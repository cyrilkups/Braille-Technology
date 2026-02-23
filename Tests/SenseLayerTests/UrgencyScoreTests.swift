import XCTest
@testable import SenseLayer

final class UrgencyScoreTests: XCTestCase {

    // MARK: - Baselines (no boost keywords)

    func testUrgentBaseline() {
        let score = CompressionService.urgencyScore(body: "Something happened", category: .urgent)
        XCTAssertEqual(score, 0.8, accuracy: 0.001)
    }

    func testWorkBaseline() {
        let score = CompressionService.urgencyScore(body: "Something happened", category: .work)
        XCTAssertEqual(score, 0.5, accuracy: 0.001)
    }

    func testPersonalBaseline() {
        let score = CompressionService.urgencyScore(body: "Something happened", category: .personal)
        XCTAssertEqual(score, 0.3, accuracy: 0.001)
    }

    func testOtherBaseline() {
        let score = CompressionService.urgencyScore(body: "Something happened", category: .other)
        XCTAssertEqual(score, 0.2, accuracy: 0.001)
    }

    // MARK: - Single boost keyword

    func testSingleBoostAddsPointOne() {
        let score = CompressionService.urgencyScore(body: "Do it now", category: .work)
        XCTAssertEqual(score, 0.6, accuracy: 0.001)
    }

    // MARK: - Multiple boost keywords stack

    func testMultipleBoostsStack() {
        let score = CompressionService.urgencyScore(body: "Fraud detected today, act now", category: .other)
        // 0.2 baseline + 3 boosts (fraud, today, now) = 0.5
        XCTAssertEqual(score, 0.5, accuracy: 0.001)
    }

    func testAllFourBoostKeywords() {
        let score = CompressionService.urgencyScore(body: "fraud today deadline now", category: .work)
        // 0.5 + 4 * 0.1 = 0.9
        XCTAssertEqual(score, 0.9, accuracy: 0.001)
    }

    // MARK: - Clamping

    func testClampedToOneWhenBoostsExceed() {
        let score = CompressionService.urgencyScore(body: "fraud today deadline now", category: .urgent)
        // 0.8 + 4 * 0.1 = 1.2 -> clamped to 1.0
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func testNeverBelowZero() {
        let score = CompressionService.urgencyScore(body: "", category: .other)
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    func testNeverAboveOne() {
        let score = CompressionService.urgencyScore(body: "fraud today deadline now", category: .urgent)
        XCTAssertLessThanOrEqual(score, 1)
    }

    // MARK: - Case insensitivity

    func testBoostIsCaseInsensitive() {
        let score = CompressionService.urgencyScore(body: "Do it NOW, DEADLINE approaching", category: .personal)
        // 0.3 + 2 * 0.1 = 0.5
        XCTAssertEqual(score, 0.5, accuracy: 0.001)
    }

    // MARK: - Duplicate keyword counted once

    func testDuplicateKeywordCountedOnce() {
        let score = CompressionService.urgencyScore(body: "now now now now", category: .other)
        // "now" appears multiple times but filter returns 1 hit
        XCTAssertEqual(score, 0.3, accuracy: 0.001)
    }
}
