import XCTest
@testable import SenseLayer

final class MessageRepositoryTests: XCTestCase {

    // MARK: - loadMessages populates classification fields

    func testLoadMessagesReturnsRequestedCount() {
        var repo = InMemoryMessageRepository(seed: 1, count: 10)
        let messages = repo.loadMessages()
        XCTAssertEqual(messages.count, 10)
    }

    func testLoadMessagesPopulatesCategory() {
        var repo = InMemoryMessageRepository(seed: 42, count: 15)
        let messages = repo.loadMessages()
        let hasNonOther = messages.contains { $0.category != .other }
        XCTAssertTrue(hasNonOther, "CompressionService should classify at least some messages as non-.other")
    }

    func testLoadMessagesPopulatesTone() {
        var repo = InMemoryMessageRepository(seed: 42, count: 50)
        let messages = repo.loadMessages()
        let hasNonCalm = messages.contains { $0.tone != .calm }
        XCTAssertTrue(hasNonCalm, "CompressionService should detect at least some non-.calm tones in a large sample")
    }

    func testLoadMessagesPopulatesUrgencyScore() {
        var repo = InMemoryMessageRepository(seed: 42, count: 15)
        let messages = repo.loadMessages()
        let scores = Set(messages.map(\.urgencyScore))
        XCTAssertTrue(scores.count > 1, "urgencyScore should vary across messages")
        for msg in messages {
            XCTAssertGreaterThanOrEqual(msg.urgencyScore, 0)
            XCTAssertLessThanOrEqual(msg.urgencyScore, 1)
        }
    }

    func testCategoryMatchesCompressionService() {
        var repo = InMemoryMessageRepository(seed: 7, count: 10)
        let messages = repo.loadMessages()
        for msg in messages {
            let expected = CompressionService.categorize(body: msg.body, senderName: msg.senderName)
            XCTAssertEqual(msg.category, expected)
        }
    }

    func testToneMatchesCompressionService() {
        var repo = InMemoryMessageRepository(seed: 7, count: 10)
        let messages = repo.loadMessages()
        for msg in messages {
            let expected = CompressionService.tone(body: msg.body)
            XCTAssertEqual(msg.tone, expected)
        }
    }

    // MARK: - markRead persists across loadMessages calls

    func testMarkReadPersists() {
        var repo = InMemoryMessageRepository(seed: 1, count: 5)
        let first = repo.loadMessages()
        let targetID = first[0].id

        XCTAssertFalse(repo.isRead(id: targetID))
        repo.markRead(id: targetID)
        XCTAssertTrue(repo.isRead(id: targetID))
    }

    func testMarkReadReflectedInSubsequentLoad() {
        var repo = InMemoryMessageRepository(seed: 1, count: 5)
        let first = repo.loadMessages()
        let targetID = first[0].id

        XCTAssertFalse(first[0].isRead)

        repo.markRead(id: targetID)
        let second = repo.loadMessages()
        let updated = second.first { $0.id == targetID }

        XCTAssertNotNil(updated)
        XCTAssertTrue(updated!.isRead)
    }

    func testUnmarkedMessagesRemainUnread() {
        var repo = InMemoryMessageRepository(seed: 1, count: 5)
        let first = repo.loadMessages()
        repo.markRead(id: first[0].id)

        let second = repo.loadMessages()
        for msg in second where msg.id != first[0].id {
            XCTAssertFalse(msg.isRead)
        }
    }

    func testMarkReadIdempotent() {
        var repo = InMemoryMessageRepository(seed: 1, count: 3)
        let msgs = repo.loadMessages()
        let id = msgs[0].id
        repo.markRead(id: id)
        repo.markRead(id: id)
        XCTAssertTrue(repo.isRead(id: id))
    }

    // MARK: - Determinism

    func testDeterministicAcrossInstances() {
        var a = InMemoryMessageRepository(seed: 99, count: 10)
        var b = InMemoryMessageRepository(seed: 99, count: 10)
        XCTAssertEqual(a.loadMessages(), b.loadMessages())
    }
}
