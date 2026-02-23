import XCTest
@preconcurrency @testable import SenseLayer

private struct StubRepository: MessageRepository {
    var messages: [Message]
    mutating func loadMessages() -> [Message] { messages }
    mutating func markRead(id: UUID) {}
    func isRead(id: UUID) -> Bool { false }
}

private func msg(_ sender: String, category: MessageCategory) -> Message {
    Message.clamped(senderName: sender, body: "body", urgencyScore: 0.5, tone: .calm, category: category)
}

nonisolated(unsafe) private let fixture = [
    msg("Boss", category: .urgent),
    msg("Mom", category: .personal),
]

private func makeState(
    mode: MockSendService.Mode,
    drafts: DraftStore = DraftStore()
) -> SenseLayerState<SpyHapticService> {
    let repo = StubRepository(messages: fixture)
    let sender = MockSendService(mode: mode)
    return SenseLayerState(repo: repo, drafts: drafts, sender: sender, haptics: SpyHapticService())
}

final class SendDraftTests: XCTestCase {

    // MARK: - Success

    @MainActor
    func testSendSuccessClearsDraft() async {
        let s = makeState(mode: .success)
        s.enterMode()
        s.startReply()
        s.currentDraft = "Hello Boss"
        await s.sendDraft()
        XCTAssertEqual(s.currentDraft, "")
    }

    @MainActor
    func testSendSuccessSetsComposingFalse() async {
        let s = makeState(mode: .success)
        s.enterMode()
        s.startReply()
        s.currentDraft = "Hello"
        await s.sendDraft()
        XCTAssertFalse(s.isComposing)
    }

    @MainActor
    func testSendSuccessPlaysSendSuccessHaptic() async {
        let s = makeState(mode: .success)
        s.enterMode()
        s.startReply()
        s.currentDraft = "Hello"
        await s.sendDraft()
        XCTAssertEqual(s.haptics.playedEvents, [.sendSuccess])
    }

    @MainActor
    func testSendSuccessClearsDraftInStore() async {
        var drafts = DraftStore()
        drafts.saveDraft(conversationKey: "Boss", text: "old draft")
        let s = makeState(mode: .success, drafts: drafts)
        s.enterMode()
        s.startReply()
        s.currentDraft = "New message"
        await s.sendDraft()
        // After success the store should be cleared for that key.
        // Verify by starting a new reply — draft should be empty.
        s.startReply()
        XCTAssertEqual(s.currentDraft, "")
    }

    // MARK: - Failure

    @MainActor
    func testSendFailureKeepsDraft() async {
        let s = makeState(mode: .failure)
        s.enterMode()
        s.startReply()
        s.currentDraft = "Important reply"
        await s.sendDraft()
        XCTAssertEqual(s.currentDraft, "Important reply")
    }

    @MainActor
    func testSendFailureRemainsComposing() async {
        let s = makeState(mode: .failure)
        s.enterMode()
        s.startReply()
        s.currentDraft = "Important reply"
        await s.sendDraft()
        XCTAssertTrue(s.isComposing)
    }

    @MainActor
    func testSendFailurePlaysSendFailureHaptic() async {
        let s = makeState(mode: .failure)
        s.enterMode()
        s.startReply()
        s.currentDraft = "Hello"
        await s.sendDraft()
        XCTAssertEqual(s.haptics.playedEvents, [.sendFailure])
    }

    // MARK: - Guards

    @MainActor
    func testSendDraftNoOpWhenNotComposing() async {
        let s = makeState(mode: .success)
        s.enterMode()
        await s.sendDraft()
        XCTAssertTrue(s.haptics.playedEvents.isEmpty)
    }

    @MainActor
    func testSendDraftNoOpWhenInactive() async {
        let s = makeState(mode: .success)
        await s.sendDraft()
        XCTAssertTrue(s.haptics.playedEvents.isEmpty)
    }
}
