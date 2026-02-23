import XCTest
@testable import SenseLayer

final class MessageTests: XCTestCase {

    // MARK: - Enum case counts

    func testMessageCategoryHasFourCases() {
        XCTAssertEqual(MessageCategory.allCases.count, 4)
    }

    func testToneHasFourCases() {
        XCTAssertEqual(Tone.allCases.count, 4)
    }

    // MARK: - Failable initializer rejects out-of-range urgencyScore

    func testInitFailsWhenUrgencyScoreIsNegative() {
        let msg = Message(
            senderName: "Alice",
            body: "Hello",
            urgencyScore: -0.1,
            tone: .calm,
            category: .personal
        )
        XCTAssertNil(msg, "urgencyScore below 0 should return nil")
    }

    func testInitFailsWhenUrgencyScoreExceedsOne() {
        let msg = Message(
            senderName: "Bob",
            body: "Alert",
            urgencyScore: 1.01,
            tone: .urgent,
            category: .urgent
        )
        XCTAssertNil(msg, "urgencyScore above 1 should return nil")
    }

    func testInitSucceedsAtLowerBound() {
        let msg = Message(
            senderName: "Carol",
            body: "Hey",
            urgencyScore: 0,
            tone: .empathy,
            category: .work
        )
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.urgencyScore, 0)
    }

    func testInitSucceedsAtUpperBound() {
        let msg = Message(
            senderName: "Dave",
            body: "Now!",
            urgencyScore: 1,
            tone: .anger,
            category: .urgent
        )
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.urgencyScore, 1)
    }

    // MARK: - Clamped factory clamps correctly

    func testClampedClampsNegativeToZero() {
        let msg = Message.clamped(
            senderName: "Eve",
            body: "Test",
            urgencyScore: -5,
            tone: .calm,
            category: .other
        )
        XCTAssertEqual(msg.urgencyScore, 0)
    }

    func testClampedClampsAboveOneToOne() {
        let msg = Message.clamped(
            senderName: "Frank",
            body: "Test",
            urgencyScore: 42,
            tone: .urgent,
            category: .work
        )
        XCTAssertEqual(msg.urgencyScore, 1)
    }

    func testClampedPreservesValidScore() {
        let msg = Message.clamped(
            senderName: "Grace",
            body: "Test",
            urgencyScore: 0.75,
            tone: .empathy,
            category: .personal
        )
        XCTAssertEqual(msg.urgencyScore, 0.75)
    }

    // MARK: - Equatable & Hashable

    func testEquatableConformance() {
        let id = UUID()
        let date = Date()
        let a = Message(id: id, senderName: "X", body: "Y", timestamp: date, urgencyScore: 0.5, tone: .calm, category: .other)
        let b = Message(id: id, senderName: "X", body: "Y", timestamp: date, urgencyScore: 0.5, tone: .calm, category: .other)
        XCTAssertEqual(a, b)
    }

    func testHashableConformance() {
        let id = UUID()
        let date = Date()
        let a = Message(id: id, senderName: "X", body: "Y", timestamp: date, urgencyScore: 0.5, tone: .calm, category: .other)!
        let b = Message(id: id, senderName: "X", body: "Y", timestamp: date, urgencyScore: 0.5, tone: .calm, category: .other)!
        XCTAssertEqual(a.hashValue, b.hashValue)

        let set: Set<Message> = [a, b]
        XCTAssertEqual(set.count, 1)
    }
}
