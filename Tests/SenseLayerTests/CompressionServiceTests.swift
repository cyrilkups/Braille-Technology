import XCTest
@testable import SenseLayer

final class CompressionServiceTests: XCTestCase {

    // MARK: - Urgent keywords

    func testUrgentFromBody() {
        let result = CompressionService.categorize(body: "This is urgent, please respond", senderName: "Alice")
        XCTAssertEqual(result, .urgent)
    }

    func testDeadlineIsUrgent() {
        let result = CompressionService.categorize(body: "The deadline is tomorrow", senderName: "Boss")
        XCTAssertEqual(result, .urgent)
    }

    func testBankIsUrgent() {
        let result = CompressionService.categorize(body: "Your bank account needs attention", senderName: "Alerts")
        XCTAssertEqual(result, .urgent)
    }

    func testFraudIsUrgent() {
        let result = CompressionService.categorize(body: "Potential fraud detected on your card", senderName: "Security")
        XCTAssertEqual(result, .urgent)
    }

    // MARK: - Work keywords

    func testMeetingIsWork() {
        let result = CompressionService.categorize(body: "Team meeting at 3 PM", senderName: "Carol")
        XCTAssertEqual(result, .work)
    }

    func testProjectIsWork() {
        let result = CompressionService.categorize(body: "Please review the project plan", senderName: "Dave")
        XCTAssertEqual(result, .work)
    }

    // MARK: - Personal keywords

    func testDinnerIsPersonal() {
        let result = CompressionService.categorize(body: "Dinner at 7 tonight?", senderName: "Jamie")
        XCTAssertEqual(result, .personal)
    }

    func testMomIsPersonal() {
        let result = CompressionService.categorize(body: "Call me back when you can", senderName: "Mom")
        XCTAssertEqual(result, .personal)
    }

    func testFamilyIsPersonal() {
        let result = CompressionService.categorize(body: "Family reunion next Sunday", senderName: "Cousin")
        XCTAssertEqual(result, .personal)
    }

    // MARK: - Other (default)

    func testUnrelatedTextIsOther() {
        let result = CompressionService.categorize(body: "Here is a random note", senderName: "Nobody")
        XCTAssertEqual(result, .other)
    }

    // MARK: - Precedence

    func testMeetingDeadlineIsUrgentNotWork() {
        let result = CompressionService.categorize(body: "The meeting deadline is today", senderName: "PM")
        XCTAssertEqual(result, .urgent, "urgent takes precedence over work")
    }

    func testFamilyUrgentIsUrgentNotPersonal() {
        let result = CompressionService.categorize(body: "Family emergency, respond immediately", senderName: "Dad")
        XCTAssertEqual(result, .urgent, "urgent takes precedence over personal")
    }

    func testMeetingDinnerIsWorkNotPersonal() {
        let result = CompressionService.categorize(body: "Client dinner meeting next week", senderName: "Boss")
        XCTAssertEqual(result, .work, "work takes precedence over personal")
    }

    // MARK: - Case insensitivity

    func testCaseInsensitive() {
        let result = CompressionService.categorize(body: "ASAP — need this now", senderName: "VP")
        XCTAssertEqual(result, .urgent)
    }

    // MARK: - Sender name contributes

    func testSenderNameContributesToClassification() {
        let result = CompressionService.categorize(body: "Hey, can you call me?", senderName: "Bank Alert")
        XCTAssertEqual(result, .urgent, "keyword in senderName should be detected")
    }
}
