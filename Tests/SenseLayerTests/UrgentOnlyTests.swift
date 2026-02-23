import XCTest
@preconcurrency @testable import SenseLayer

private struct UrgentOnlyRepo: MessageRepository {
    var messages: [Message]

    mutating func loadMessages() -> [Message] { messages }
    mutating func markRead(id: UUID) {}
    func isRead(id: UUID) -> Bool { false }
}

private func makeUrgentOnlyState() -> SenseLayerState<SpyHapticService> {
    let messages = [
        Message.clamped(
            senderName: "Friend",
            body: "Lunch at noon?",
            urgencyScore: 0.3,
            tone: .calm,
            category: .personal
        ),
        Message.clamped(
            senderName: "Bank Alert",
            body: "Fraud alert: unusual transaction detected.",
            urgencyScore: 0.98,
            tone: .urgent,
            category: .urgent
        ),
        Message.clamped(
            senderName: "PM",
            body: "Roadmap draft update",
            urgencyScore: 0.4,
            tone: .calm,
            category: .work
        ),
    ]
    let repo = UrgentOnlyRepo(messages: messages)
    return SenseLayerState(repo: repo, haptics: SpyHapticService())
}

final class UrgentOnlyTests: XCTestCase {

    func testUrgentOnlyImmediatelyReducesHomeNoiseToUrgent() {
        let s = makeUrgentOnlyState()
        s.enterMode()

        XCTAssertEqual(s.homeTopMessage?.senderName, "Friend")

        s.toggleUrgentOnly()

        XCTAssertTrue(s.isUrgentOnlyEnabled)
        XCTAssertEqual(s.homeTopMessage?.senderName, "Bank Alert")
        XCTAssertEqual(s.homeTopMessage?.category, .urgent)
    }

    func testUrgentOnlyPlaysConfirmationPulse() {
        let s = makeUrgentOnlyState()
        s.enterMode()

        s.toggleUrgentOnly()

        XCTAssertEqual(s.haptics.playedEvents.last, .sendSuccess)
    }

    func testUrgentOnlyUsesUrgentTactileSignature() {
        let s = makeUrgentOnlyState()
        s.enterMode()
        s.toggleUrgentOnly()

        s.beginTactileReading()

        XCTAssertEqual(s.haptics.tactileReadingStartSignatures.last, .urgent)
    }

    func testExitModeClearsUrgentOnly() {
        let s = makeUrgentOnlyState()
        s.enterMode()
        s.toggleUrgentOnly()

        s.exitMode()

        XCTAssertFalse(s.isUrgentOnlyEnabled)
    }
}
