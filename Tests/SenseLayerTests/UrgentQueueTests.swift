import XCTest
@preconcurrency @testable import SenseLayer

private struct StubRepository: MessageRepository {
    var messages: [Message]
    mutating func loadMessages() -> [Message] { messages }
    mutating func markRead(id: UUID) {}
    func isRead(id: UUID) -> Bool { false }
}

private func urgentMsg(_ sender: String = "Alert") -> Message {
    Message.clamped(senderName: sender, body: "Urgent incoming", urgencyScore: 0.9, tone: .urgent, category: .urgent)
}

private func personalMsg(_ sender: String = "Friend") -> Message {
    Message.clamped(senderName: sender, body: "Hey there", urgencyScore: 0.3, tone: .calm, category: .personal)
}

nonisolated(unsafe) private let fixture = [
    Message.clamped(senderName: "Boss", body: "Task", urgencyScore: 0.5, tone: .calm, category: .urgent),
    Message.clamped(senderName: "Mom", body: "Dinner", urgencyScore: 0.3, tone: .calm, category: .personal),
]

private func makeState() -> SenseLayerState<SpyHapticService> {
    let repo = StubRepository(messages: fixture)
    return SenseLayerState(repo: repo, haptics: SpyHapticService())
}

final class UrgentQueueTests: XCTestCase {

    // MARK: - Receiving while active

    func testReceiveUrgentDoesNotTriggerHaptic() {
        let s = makeState()
        s.enterMode()
        s.receiveNewMessage(urgentMsg())
        XCTAssertTrue(s.haptics.playedEvents.isEmpty, "No immediate haptic on receive")
    }

    func testReceiveUrgentQueuesMessage() {
        let s = makeState()
        s.enterMode()
        s.receiveNewMessage(urgentMsg())
        XCTAssertEqual(s.urgentQueue.count, 1)
    }

    func testReceiveMultipleUrgentQueuesAll() {
        let s = makeState()
        s.enterMode()
        s.receiveNewMessage(urgentMsg("A"))
        s.receiveNewMessage(urgentMsg("B"))
        s.receiveNewMessage(urgentMsg("C"))
        XCTAssertEqual(s.urgentQueue.count, 3)
    }

    func testReceiveNonUrgentDoesNotQueue() {
        let s = makeState()
        s.enterMode()
        s.receiveNewMessage(personalMsg())
        XCTAssertTrue(s.urgentQueue.isEmpty)
    }

    func testReceiveAddsToAllMessages() {
        let s = makeState()
        s.enterMode()
        let before = s.messagesInActiveCategory.count
        s.receiveNewMessage(urgentMsg())
        let after = s.messagesInActiveCategory.count
        XCTAssertEqual(after, before + 1)
    }

    func testReceiveWhenInactiveIsIgnored() {
        let s = makeState()
        s.receiveNewMessage(urgentMsg())
        XCTAssertTrue(s.urgentQueue.isEmpty)
    }

    // MARK: - exitCategoryToDashboard drains queue

    func testExitCategoryPlaysUrgentQueuedAlertOnce() {
        let s = makeState()
        s.enterMode()
        s.receiveNewMessage(urgentMsg("A"))
        s.receiveNewMessage(urgentMsg("B"))
        s.exitCategoryToDashboard()
        XCTAssertEqual(s.haptics.playedEvents, [.urgentQueuedAlert])
    }

    func testExitCategoryClearsQueue() {
        let s = makeState()
        s.enterMode()
        s.receiveNewMessage(urgentMsg())
        s.exitCategoryToDashboard()
        XCTAssertTrue(s.urgentQueue.isEmpty)
    }

    func testExitCategoryNoHapticWhenQueueEmpty() {
        let s = makeState()
        s.enterMode()
        s.exitCategoryToDashboard()
        XCTAssertTrue(s.haptics.playedEvents.isEmpty)
    }

    func testExitCategoryResetsNavigation() {
        let s = makeState()
        s.enterMode()
        s.nextCategory()
        s.exitCategoryToDashboard()
        XCTAssertEqual(s.activeCategoryIndex, 0)
        XCTAssertEqual(s.activeMessageIndex, 0)
        XCTAssertEqual(s.readingMode, .summary)
    }

    // MARK: - exitMode also drains queue

    func testExitModePlaysUrgentQueuedAlert() {
        let s = makeState()
        s.enterMode()
        s.receiveNewMessage(urgentMsg())
        s.exitMode()
        XCTAssertEqual(s.haptics.playedEvents, [.urgentQueuedAlert])
        XCTAssertTrue(s.urgentQueue.isEmpty)
    }

    func testExitModeNoAlertWhenQueueEmpty() {
        let s = makeState()
        s.enterMode()
        s.exitMode()
        XCTAssertTrue(s.haptics.playedEvents.isEmpty)
    }

    // MARK: - Alert fires only once per drain

    func testAlertFiresOnlyOnceRegardlessOfQueueSize() {
        let s = makeState()
        s.enterMode()
        for i in 0..<5 {
            s.receiveNewMessage(urgentMsg("Sender\(i)"))
        }
        s.exitCategoryToDashboard()
        let alertCount = s.haptics.playedEvents.filter { $0 == .urgentQueuedAlert }.count
        XCTAssertEqual(alertCount, 1)
    }

    // MARK: - Draft saved on exitCategoryToDashboard

    func testDraftSavedOnExitCategoryToDashboard() {
        let s = makeState()
        s.enterMode()
        s.startReply()
        s.currentDraft = "WIP"
        s.exitCategoryToDashboard()
        s.startReply()
        XCTAssertEqual(s.currentDraft, "WIP")
    }
}
