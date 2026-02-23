import XCTest
@preconcurrency @testable import SenseLayer

private func msg(_ sender: String, body: String, category: MessageCategory = .personal) -> Message {
    Message.clamped(senderName: sender, body: body, urgencyScore: 0.5, tone: .calm, category: category)
}

private struct StubRepo: MessageRepository {
    var messages: [Message]
    mutating func loadMessages() -> [Message] { messages }
    mutating func markRead(id: UUID) {}
    func isRead(id: UUID) -> Bool { false }
}

nonisolated(unsafe) private let fixture = [
    msg("Mom", body: "Birthday dinner Sunday at 6"),
    msg("Team", body: "Standup moved to 10 AM", category: .work),
    msg("Bank", body: "Your balance is low", category: .urgent),
]

private func makeState(
    sendMode: MockSendService.Mode = .success,
    drafts: DraftStore = DraftStore()
) -> SenseLayerState<SpyHapticService> {
    let repo = StubRepo(messages: fixture)
    let sender = MockSendService(mode: sendMode)
    return SenseLayerState(repo: repo, drafts: drafts, sender: sender, haptics: SpyHapticService())
}

/// Simulates the full flow: Home → Messages → pick conversation → read → reply → send.
final class MessagesFlowTests: XCTestCase {

    // MARK: - Navigation flow

    func testNavigateToConversations() {
        let s = makeState()
        s.enterMode()
        s.enterNavigateMode(.conversations(appID: "Messages"))

        XCTAssertEqual(s.currentMode, .navigate(context: .conversations(appID: "Messages")))
        XCTAssertTrue(s.conversations.contains(where: { $0.senderName == "Mom" }))
    }

    func testSelectConversationEntersReadMode() {
        let s = makeState()
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))

        if case .read(let ctx) = s.currentMode {
            XCTAssertEqual(ctx.message.senderName, "Mom")
            XCTAssertEqual(ctx.appName, "Messages")
        } else {
            XCTFail("Expected read mode")
        }
    }

    // MARK: - Reply + Send success

    func testStartReplyInReadMode() {
        let s = makeState()
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()

        XCTAssertTrue(s.isComposing)
        XCTAssertEqual(s.composeDotMask, 0)
        XCTAssertEqual(s.currentDraft, "")
    }

    @MainActor
    func testSendSuccessClearsDraftAndExitsCompose() async {
        let s = makeState(sendMode: .success)
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()
        s.currentDraft = "ok"

        await s.sendDraft()

        XCTAssertEqual(s.currentDraft, "")
        XCTAssertFalse(s.isComposing)
        XCTAssertEqual(s.lastSendResult, .sent)
        XCTAssertTrue(s.haptics.playedEvents.contains(.sendSuccess))

        // Still in read mode (returned to conversation view)
        if case .read(let ctx) = s.currentMode {
            XCTAssertEqual(ctx.message.senderName, "Mom")
        } else {
            XCTFail("Expected to remain in read mode after send success")
        }
    }

    // MARK: - Reply + Send failure

    @MainActor
    func testSendFailurePreservesDraft() async {
        let s = makeState(sendMode: .failure)
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()
        s.currentDraft = "ok"

        await s.sendDraft()

        XCTAssertEqual(s.currentDraft, "ok")
        XCTAssertTrue(s.isComposing)
        XCTAssertEqual(s.lastSendResult, .failed)
        XCTAssertTrue(s.haptics.playedEvents.contains(.sendFailure))
    }

    // MARK: - Braille compose

    func testToggleDotUpdatesComposeMask() {
        let s = makeState()
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()

        s.toggleDot(0) // dot 1
        XCTAssertEqual(s.composeDotMask, 1)

        s.toggleDot(1) // dot 2
        XCTAssertEqual(s.composeDotMask, 3) // 0b11

        s.toggleDot(0) // un-toggle dot 1
        XCTAssertEqual(s.composeDotMask, 2) // 0b10
    }

    func testCommitBrailleCharAppendsCharacter() {
        let s = makeState()
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()

        // 'a' = dot1 only = bitmask 1
        s.toggleDot(0)
        s.commitBrailleChar()

        XCTAssertEqual(s.currentDraft, "a")
        XCTAssertEqual(s.composeDotMask, 0)
    }

    func testCommitWithNoDotSelectedIsNoOp() {
        let s = makeState()
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()

        s.commitBrailleChar()

        XCTAssertEqual(s.currentDraft, "")
    }

    func testCommitSpaceAppendsSpace() {
        let s = makeState()
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()

        // Type 'a' then space
        s.toggleDot(0)
        s.commitBrailleChar()
        s.commitSpace()

        XCTAssertEqual(s.currentDraft, "a ")
    }

    func testDeleteLastCharRemovesCharacter() {
        let s = makeState()
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()

        s.toggleDot(0)
        s.commitBrailleChar()
        XCTAssertEqual(s.currentDraft, "a")

        s.deleteLastChar()
        XCTAssertEqual(s.currentDraft, "")
    }

    // MARK: - Back from compose returns to read

    func testTakeMeBackFromComposeExitsCompose() {
        let s = makeState()
        s.enterMode()

        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))
        s.startReply()
        s.currentDraft = "partial"

        s.takeMeBack()

        XCTAssertFalse(s.isComposing)
        // Still in read mode
        if case .read(let ctx) = s.currentMode {
            XCTAssertEqual(ctx.message.senderName, "Mom")
        } else {
            XCTFail("Expected to remain in read mode after backing out of compose")
        }
    }

    // MARK: - Full flow: type "ok" and send

    @MainActor
    func testFullFlowTypeOkAndSend() async {
        let s = makeState(sendMode: .success)
        s.enterMode()

        // Navigate to Messages conversations
        s.enterNavigateMode(.conversations(appID: "Messages"))

        // Pick Mom
        let momMsg = s.messageFrom(senderName: "Mom")!
        s.enterReadMode(ReadContext(message: momMsg, appName: "Messages"))

        // Start reply
        s.startReply()
        XCTAssertTrue(s.isComposing)

        // Type 'o' = dots 1,3,5 = bitmask 0b010101 = 21
        s.toggleDot(0) // dot1
        s.toggleDot(2) // dot3
        s.toggleDot(4) // dot5
        s.commitBrailleChar()
        XCTAssertEqual(s.currentDraft, "o")

        // Type 'k' = dots 1,3 = bitmask 0b000101 = 5
        s.toggleDot(0) // dot1
        s.toggleDot(2) // dot3
        s.commitBrailleChar()
        XCTAssertEqual(s.currentDraft, "ok")

        // Send
        await s.sendDraft()

        XCTAssertEqual(s.lastSendResult, .sent)
        XCTAssertEqual(s.currentDraft, "")
        XCTAssertFalse(s.isComposing)

        // Back to read mode (Mom's conversation)
        if case .read(let ctx) = s.currentMode {
            XCTAssertEqual(ctx.message.senderName, "Mom")
        } else {
            XCTFail("Expected read mode after successful send")
        }
    }
}
