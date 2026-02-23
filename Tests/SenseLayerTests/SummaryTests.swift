import XCTest
@testable import SenseLayer

final class SummaryTests: XCTestCase {

    // MARK: - Short body returned unchanged

    func testShortBodyUnchanged() {
        let body = "Pick up milk on the way home."
        let result = CompressionService.summary(body: body)
        XCTAssertEqual(result, body)
    }

    func testExactlyAtLimitUnchanged() {
        let body = String(repeating: "a", count: 120)
        let result = CompressionService.summary(body: body, maxChars: 120)
        XCTAssertEqual(result, body)
        XCTAssertEqual(result.count, 120)
    }

    // MARK: - Long body truncated with ellipsis

    func testLongBodyTruncatedWithEllipsis() {
        let body = String(repeating: "x", count: 200)
        let result = CompressionService.summary(body: body, maxChars: 120)
        XCTAssertTrue(result.hasSuffix("\u{2026}"))
        XCTAssertEqual(result.count, 120)
    }

    func testOneOverLimitTruncates() {
        let body = String(repeating: "b", count: 121)
        let result = CompressionService.summary(body: body, maxChars: 120)
        XCTAssertEqual(result.count, 120)
        XCTAssertTrue(result.hasSuffix("\u{2026}"))
    }

    func testCustomMaxChars() {
        let body = "This sentence is longer than ten characters."
        let result = CompressionService.summary(body: body, maxChars: 10)
        XCTAssertEqual(result.count, 10)
        XCTAssertTrue(result.hasSuffix("\u{2026}"))
    }

    // MARK: - Newlines removed

    func testNewlinesReplacedWithSpaces() {
        let body = "Line one\nLine two\nLine three"
        let result = CompressionService.summary(body: body)
        XCTAssertFalse(result.contains("\n"))
        XCTAssertEqual(result, "Line one Line two Line three")
    }

    func testCarriageReturnNewlinesRemoved() {
        let body = "Hello\r\nWorld\r\nTest"
        let result = CompressionService.summary(body: body)
        XCTAssertFalse(result.contains("\r"))
        XCTAssertFalse(result.contains("\n"))
        XCTAssertEqual(result, "Hello World Test")
    }

    func testNewlinesAndTruncationCombined() {
        let body = "First line\nSecond line\nThird line that keeps going and going and going to make it really quite long indeed so it exceeds the limit"
        let result = CompressionService.summary(body: body, maxChars: 40)
        XCTAssertFalse(result.contains("\n"))
        XCTAssertLessThanOrEqual(result.count, 40)
        XCTAssertTrue(result.hasSuffix("\u{2026}"))
    }

    // MARK: - Edge cases

    func testEmptyBodyReturnsEmpty() {
        XCTAssertEqual(CompressionService.summary(body: ""), "")
    }

    func testWhitespaceOnlyBodyReturnsTrimmed() {
        XCTAssertEqual(CompressionService.summary(body: "   "), "")
    }
}
