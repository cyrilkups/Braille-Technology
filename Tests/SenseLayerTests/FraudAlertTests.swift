import XCTest
@preconcurrency @testable import SenseLayer

private struct FraudConversationRepo: MessageRepository {
    var messages: [Message]

    mutating func loadMessages() -> [Message] { messages }
    mutating func markRead(id: UUID) {}
    func isRead(id: UUID) -> Bool { false }
}

private func fraudMsg(_ sender: String, body: String, category: MessageCategory) -> Message {
    Message.clamped(
        senderName: sender,
        body: body,
        urgencyScore: 0.9,
        tone: .urgent,
        category: category
    )
}

final class FraudAlertTests: XCTestCase {

    private func makeState(scenario: DemoScenario? = .bankFraud) -> SenseLayerState<SpyHapticService> {
        let repo = InMemoryMessageRepository(seed: 1, count: 5)
        let s = SenseLayerState(repo: repo, haptics: SpyHapticService())
        if let scenario { s.selectDemoScenario(scenario) }
        s.enterMode()
        return s
    }

    // MARK: - Entry

    func testEnterModeWithBankFraudStartsAlertPhase() {
        let s = makeState()
        XCTAssertEqual(s.fraudAlertPhase, .alert)
    }

    func testEnterModeWithBankFraudPlaysUrgentTriplePulse() {
        let s = makeState()
        XCTAssertTrue(s.haptics.playedEvents.contains(.urgentTriplePulse))
    }

    func testEnterModeWithoutFraudHasNoFraudPhase() {
        let s = makeState(scenario: .momBirthday)
        XCTAssertNil(s.fraudAlertPhase)
    }

    func testEnterModeWithNilScenarioHasNoFraudPhase() {
        let s = makeState(scenario: nil)
        XCTAssertNil(s.fraudAlertPhase)
    }

    // MARK: - Freeze Card

    func testFreezeCardTransitionsToFrozen() {
        let s = makeState()
        s.fraudFreezeCard()
        XCTAssertEqual(s.fraudAlertPhase, .frozen)
    }

    func testFreezeCardPlaysFreezeConfirm() {
        let s = makeState()
        s.fraudFreezeCard()
        XCTAssertTrue(s.haptics.playedEvents.contains(.freezeConfirm))
    }

    func testFreezeCardIgnoredWhenNotInAlert() {
        let s = makeState()
        s.fraudFreezeCard()
        XCTAssertEqual(s.fraudAlertPhase, .frozen)
        s.fraudFreezeCard()
        XCTAssertEqual(s.fraudAlertPhase, .frozen, "Should not change when already frozen")
    }

    // MARK: - Call Bank

    func testCallBankTransitionsToCalling() {
        let s = makeState()
        s.fraudCallBank()
        XCTAssertEqual(s.fraudAlertPhase, .calling)
    }

    func testCallBankPlaysActivate() {
        let s = makeState()
        s.fraudCallBank()
        XCTAssertTrue(s.haptics.playedEvents.contains(.activate))
    }

    func testCallBankIgnoredWhenFrozen() {
        let s = makeState()
        s.fraudFreezeCard()
        s.fraudCallBank()
        XCTAssertEqual(s.fraudAlertPhase, .frozen, "Should stay frozen")
    }

    // MARK: - Dismiss / Ignore

    func testDismissClearsFraudPhase() {
        let s = makeState()
        s.fraudDismiss()
        XCTAssertNil(s.fraudAlertPhase)
    }

    func testDismissFromFrozenClearsFraudPhase() {
        let s = makeState()
        s.fraudFreezeCard()
        s.fraudDismiss()
        XCTAssertNil(s.fraudAlertPhase)
    }

    func testDismissPlaysCategorySwitch() {
        let s = makeState()
        let countBefore = s.haptics.playedEvents.filter { $0 == .categorySwitch }.count
        s.fraudDismiss()
        let countAfter = s.haptics.playedEvents.filter { $0 == .categorySwitch }.count
        XCTAssertEqual(countAfter, countBefore + 1)
    }

    // MARK: - Full flow

    func testFullFraudFlow() {
        let s = makeState()

        XCTAssertEqual(s.fraudAlertPhase, .alert)
        XCTAssertTrue(s.haptics.playedEvents.contains(.urgentTriplePulse))

        s.fraudFreezeCard()
        XCTAssertEqual(s.fraudAlertPhase, .frozen)
        XCTAssertTrue(s.haptics.playedEvents.contains(.freezeConfirm))

        s.fraudDismiss()
        XCTAssertNil(s.fraudAlertPhase)
        XCTAssertEqual(s.currentMode, .home)
    }

    func testIgnoreFlowReturnsToNormalHome() {
        let s = makeState()
        XCTAssertEqual(s.fraudAlertPhase, .alert)

        s.fraudDismiss()
        XCTAssertNil(s.fraudAlertPhase)
        XCTAssertEqual(s.currentMode, .home)
    }

    // MARK: - Conversation selection

    func testOpenConversationBankAlertTriggersFraudScenario() {
        let repo = FraudConversationRepo(messages: [
            fraudMsg("Mom", body: "Dinner at 7?", category: .personal),
            fraudMsg(
                "Bank Alert",
                body: "Fraud alert: card ending 8842 charged $942.13 at 2:14 AM.",
                category: .urgent),
        ])
        let s = SenseLayerState(repo: repo, haptics: SpyHapticService())
        s.enterMode()
        s.enterNavigateMode(.conversations(appID: "Messages"))

        s.openConversation(senderName: "Bank Alert", appID: "Messages")

        XCTAssertEqual(s.currentMode, .home)
        XCTAssertEqual(s.fraudAlertPhase, .alert)
        XCTAssertTrue(s.haptics.playedEvents.contains(.urgentTriplePulse))
    }

    func testOpenConversationNonBankEntersReadMode() {
        let repo = FraudConversationRepo(messages: [
            fraudMsg("Mom", body: "Dinner at 7?", category: .personal),
            fraudMsg(
                "Bank Alert",
                body: "Fraud alert: card ending 8842 charged $942.13 at 2:14 AM.",
                category: .urgent),
        ])
        let s = SenseLayerState(repo: repo, haptics: SpyHapticService())
        s.enterMode()
        s.enterNavigateMode(.conversations(appID: "Messages"))

        s.openConversation(senderName: "Mom", appID: "Messages")

        XCTAssertNil(s.fraudAlertPhase)
        if case .read(let context) = s.currentMode {
            XCTAssertEqual(context.message.senderName, "Mom")
            XCTAssertEqual(context.appName, "Messages")
        } else {
            XCTFail("Expected read mode for non-bank sender")
        }
    }
}
