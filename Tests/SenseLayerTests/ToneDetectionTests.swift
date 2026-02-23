import XCTest
@testable import SenseLayer

final class ToneDetectionTests: XCTestCase {

    // MARK: - Anger

    func testAngerFromAggressivePhrase() {
        XCTAssertEqual(CompressionService.tone(body: "This is absolutely unacceptable"), .anger)
    }

    func testAngerFromProfanity() {
        XCTAssertEqual(CompressionService.tone(body: "What the hell is going on here"), .anger)
    }

    func testAngerFromExclamationPlusNegative() {
        XCTAssertEqual(CompressionService.tone(body: "This is terrible!! I can't believe it"), .anger)
    }

    func testExclamationAloneIsNotAnger() {
        XCTAssertNotEqual(CompressionService.tone(body: "Great news!! We won the award"), .anger)
    }

    func testNegativeWordAloneIsNotAnger() {
        XCTAssertNotEqual(CompressionService.tone(body: "That was a terrible movie"), .anger)
    }

    // MARK: - Empathy

    func testEmpathyFromSorry() {
        XCTAssertEqual(CompressionService.tone(body: "I'm so sorry for your loss"), .empathy)
    }

    func testEmpathyFromThinkingOfYou() {
        XCTAssertEqual(CompressionService.tone(body: "Just thinking of you today"), .empathy)
    }

    func testEmpathyFromHereForYou() {
        XCTAssertEqual(CompressionService.tone(body: "I'm here for you, always"), .empathy)
    }

    func testEmpathyFromPraying() {
        XCTAssertEqual(CompressionService.tone(body: "Praying for a speedy recovery"), .empathy)
    }

    // MARK: - Urgent

    func testUrgentFromAsap() {
        XCTAssertEqual(CompressionService.tone(body: "Send the report ASAP"), .urgent)
    }

    func testUrgentFromImmediately() {
        XCTAssertEqual(CompressionService.tone(body: "Please respond immediately"), .urgent)
    }

    func testUrgentFromDeadline() {
        XCTAssertEqual(CompressionService.tone(body: "The deadline is in one hour"), .urgent)
    }

    // MARK: - Calm (default)

    func testCalmForNeutralText() {
        XCTAssertEqual(CompressionService.tone(body: "See you at the park tomorrow"), .calm)
    }

    func testCalmForEmptyBody() {
        XCTAssertEqual(CompressionService.tone(body: ""), .calm)
    }

    // MARK: - Precedence

    func testAngerBeatsUrgent() {
        let result = CompressionService.tone(body: "This is unacceptable, fix it now immediately")
        XCTAssertEqual(result, .anger, "anger takes precedence over urgent")
    }

    func testAngerBeatsEmpathy() {
        let result = CompressionService.tone(body: "I'm sorry but this is absolutely ridiculous")
        XCTAssertEqual(result, .anger, "anger takes precedence over empathy")
    }

    func testEmpathyBeatsUrgent() {
        let result = CompressionService.tone(body: "I'm sorry, please respond now if you can")
        XCTAssertEqual(result, .empathy, "empathy takes precedence over urgent")
    }

    // MARK: - Case insensitivity

    func testCaseInsensitiveAnger() {
        XCTAssertEqual(CompressionService.tone(body: "HOW DARE you speak to me that way"), .anger)
    }

    func testCaseInsensitiveEmpathy() {
        XCTAssertEqual(CompressionService.tone(body: "THINKING OF YOU during this time"), .empathy)
    }
}
