import XCTest
@testable import SenseLayer

final class MockMessageFactoryTests: XCTestCase {

    // MARK: - Determinism: same seed + count => identical output

    func testSameSeedProducesIdenticalIDs() {
        let a = MockMessageFactory.generate(seed: 42, count: 10)
        let b = MockMessageFactory.generate(seed: 42, count: 10)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
    }

    func testSameSeedProducesIdenticalBodies() {
        let a = MockMessageFactory.generate(seed: 42, count: 10)
        let b = MockMessageFactory.generate(seed: 42, count: 10)
        XCTAssertEqual(a.map(\.body), b.map(\.body))
    }

    func testSameSeedProducesIdenticalMessages() {
        let a = MockMessageFactory.generate(seed: 99, count: 5)
        let b = MockMessageFactory.generate(seed: 99, count: 5)
        XCTAssertEqual(a, b)
    }

    // MARK: - Different seeds => different output

    func testDifferentSeedProducesDifferentOutput() {
        let a = MockMessageFactory.generate(seed: 1, count: 10)
        let b = MockMessageFactory.generate(seed: 2, count: 10)
        XCTAssertNotEqual(a.map(\.id), b.map(\.id))
    }

    // MARK: - Count matches requested count

    func testCountMatchesRequested() {
        for n in [0, 1, 5, 20, 100] {
            let messages = MockMessageFactory.generate(seed: 7, count: n)
            XCTAssertEqual(messages.count, n, "Expected \(n) messages")
        }
    }

    // MARK: - Basic sanity

    func testAllMessagesHaveValidUrgencyScore() {
        let messages = MockMessageFactory.generate(seed: 0, count: 50)
        for msg in messages {
            XCTAssertGreaterThanOrEqual(msg.urgencyScore, 0)
            XCTAssertLessThanOrEqual(msg.urgencyScore, 1)
        }
    }

    func testBodiesAreNonEmpty() {
        let messages = MockMessageFactory.generate(seed: 13, count: 20)
        for msg in messages {
            XCTAssertFalse(msg.body.isEmpty)
            XCTAssertFalse(msg.senderName.isEmpty)
        }
    }
}
