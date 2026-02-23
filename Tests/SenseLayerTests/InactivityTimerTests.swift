import XCTest
@preconcurrency @testable import SenseLayer

private struct StubRepository: MessageRepository {
    var messages: [Message]
    mutating func loadMessages() -> [Message] { messages }
    mutating func markRead(id: UUID) {}
    func isRead(id: UUID) -> Bool { false }
}

nonisolated(unsafe) private let fixture = [
    Message.clamped(senderName: "Boss", body: "Alert", urgencyScore: 0.5, tone: .calm, category: .urgent),
    Message.clamped(senderName: "Mom", body: "Dinner", urgencyScore: 0.3, tone: .calm, category: .personal),
]

private func makeState(
    scheduler: TestScheduler,
    drafts: DraftStore = DraftStore()
) -> SenseLayerState<SpyHapticService> {
    let repo = StubRepository(messages: fixture)
    return SenseLayerState(
        repo: repo,
        drafts: drafts,
        scheduler: scheduler,
        haptics: SpyHapticService()
    )
}

final class InactivityTimerTests: XCTestCase {

    // MARK: - Timer fires after 60 seconds

    func testAutoExitAfter60Seconds() {
        let clock = TestScheduler()
        let s = makeState(scheduler: clock)
        s.enterMode()
        XCTAssertTrue(s.isActive)

        clock.advance(by: 60)
        XCTAssertFalse(s.isActive, "Should auto-exit after 60s of inactivity")
    }

    func testNoAutoExitBefore60Seconds() {
        let clock = TestScheduler()
        let s = makeState(scheduler: clock)
        s.enterMode()

        clock.advance(by: 59)
        XCTAssertTrue(s.isActive)
    }

    // MARK: - registerInteraction resets timer

    func testInteractionResetsTimer() {
        let clock = TestScheduler()
        let s = makeState(scheduler: clock)
        s.enterMode()

        clock.advance(by: 50)
        s.registerInteraction()

        clock.advance(by: 50)
        XCTAssertTrue(s.isActive, "Timer was reset; 50s since last interaction")

        clock.advance(by: 10)
        XCTAssertFalse(s.isActive, "60s since last interaction; should auto-exit")
    }

    func testMultipleInteractionsKeepAlive() {
        let clock = TestScheduler()
        let s = makeState(scheduler: clock)
        s.enterMode()

        for _ in 0..<10 {
            clock.advance(by: 55)
            s.registerInteraction()
        }
        XCTAssertTrue(s.isActive, "Repeated interactions should prevent exit")

        clock.advance(by: 60)
        XCTAssertFalse(s.isActive)
    }

    // MARK: - Draft saved on auto-exit

    func testDraftSavedOnAutoExit() {
        let clock = TestScheduler()
        let s = makeState(scheduler: clock)
        s.enterMode()
        s.startReply()
        s.currentDraft = "Work in progress"

        clock.advance(by: 60)
        XCTAssertFalse(s.isActive)
        XCTAssertFalse(s.isComposing)

        // Re-enter and verify draft was persisted
        s.enterMode()
        s.startReply()
        XCTAssertEqual(s.currentDraft, "Work in progress")
    }

    // MARK: - exitMode cancels timer

    func testExitModeCancelsTimer() {
        let clock = TestScheduler()
        let s = makeState(scheduler: clock)
        s.enterMode()
        s.exitMode()

        clock.advance(by: 120)
        // exitMode already called; the timer should not cause issues
        XCTAssertFalse(s.isActive)
        XCTAssertEqual(clock.pendingCount, 0)
    }

    // MARK: - registerInteraction no-op when inactive

    func testRegisterInteractionNoOpWhenInactive() {
        let clock = TestScheduler()
        let s = makeState(scheduler: clock)
        s.registerInteraction()
        XCTAssertEqual(clock.pendingCount, 0)
    }

    // MARK: - enterMode resets timer

    func testReEnterModeResetsTimer() {
        let clock = TestScheduler()
        let s = makeState(scheduler: clock)
        s.enterMode()
        clock.advance(by: 30)
        s.exitMode()

        s.enterMode()
        clock.advance(by: 59)
        XCTAssertTrue(s.isActive, "Fresh 60s timer from second enterMode")

        clock.advance(by: 1)
        XCTAssertFalse(s.isActive)
    }
}
