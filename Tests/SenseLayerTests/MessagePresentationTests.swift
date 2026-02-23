import XCTest
@testable import SenseLayer

final class MessagePresentationTests: XCTestCase {

    private func makePresentation(body: String, sender: String = "Alice") -> MessagePresentation {
        let msg = Message.clamped(
            senderName: sender,
            body: body,
            urgencyScore: 0.5,
            tone: .calm,
            category: .other
        )
        return MessagePresentation(message: msg)
    }

    // MARK: - Summary

    func testSummaryShortBodyUnchanged() {
        let p = makePresentation(body: "Quick note")
        XCTAssertEqual(p.summary, "Quick note")
    }

    func testSummaryLengthNeverExceeds120() {
        let longBody = String(repeating: "word ", count: 50)
        let p = makePresentation(body: longBody)
        XCTAssertLessThanOrEqual(p.summary.count, 120)
    }

    func testSummaryLongBodyEndsWithEllipsis() {
        let longBody = String(repeating: "a", count: 200)
        let p = makePresentation(body: longBody)
        XCTAssertTrue(p.summary.hasSuffix("\u{2026}"))
    }

    // MARK: - Conversation key

    func testConversationKeyEqualsSenderName() {
        let p = makePresentation(body: "Hello", sender: "Bob")
        XCTAssertEqual(p.conversationKey, "Bob")
    }

    func testConversationKeyPreservesCase() {
        let p = makePresentation(body: "Hi", sender: "Dr. Patel")
        XCTAssertEqual(p.conversationKey, "Dr. Patel")
    }

    // MARK: - Identity delegates to Message

    func testIdMatchesMessageId() {
        let msg = Message.clamped(
            senderName: "Eve",
            body: "Test",
            urgencyScore: 0.3,
            tone: .calm,
            category: .personal
        )
        let p = MessagePresentation(message: msg)
        XCTAssertEqual(p.id, msg.id)
    }

    // MARK: - Equatable / Hashable

    func testEqualPresentationsFromSameMessage() {
        let msg = Message.clamped(
            senderName: "X",
            body: "Y",
            urgencyScore: 0.5,
            tone: .calm,
            category: .other
        )
        let a = MessagePresentation(message: msg)
        let b = MessagePresentation(message: msg)
        XCTAssertEqual(a, b)
    }
}
