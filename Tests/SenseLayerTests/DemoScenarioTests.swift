import XCTest
@preconcurrency @testable import SenseLayer

private struct DemoStubRepository: MessageRepository {
    var messages: [Message]

    mutating func loadMessages() -> [Message] { messages }
    mutating func markRead(id: UUID) {}
    func isRead(id: UUID) -> Bool { false }
}

private func repoMessage(_ body: String) -> Message {
    Message.clamped(
        senderName: "Repo",
        body: body,
        urgencyScore: 0.5,
        tone: .calm,
        category: .other
    )
}

private func makeState() -> SenseLayerState<SpyHapticService> {
    let repo = DemoStubRepository(messages: [repoMessage("repo baseline")])
    return SenseLayerState(repo: repo, haptics: SpyHapticService())
}

final class DemoScenarioTests: XCTestCase {

    func testBankFraudScenarioImmediatelyFocusesUrgentWithFraudAlert() {
        let s = makeState()
        s.enterMode()

        s.selectDemoScenario(.bankFraud)

        XCTAssertEqual(s.categories[s.activeCategoryIndex], .urgent)
        XCTAssertEqual(s.currentMessage?.senderName, "Bank Alert")
        XCTAssertTrue(
            s.currentMessage?.body.localizedCaseInsensitiveContains("fraud alert") ?? false
        )
    }

    func testMomBirthdayScenarioAppearsUnderPersonal() {
        let s = makeState()
        s.selectDemoScenario(.momBirthday)
        s.enterMode()

        XCTAssertEqual(s.categories[s.activeCategoryIndex], .personal)

        let personalMessages = s.messagesInActiveCategory
        XCTAssertTrue(personalMessages.contains { $0.senderName == "Mom" })
        XCTAssertTrue(personalMessages.contains {
            $0.body.localizedCaseInsensitiveContains("birthday")
        })
    }

    func testOverloadFilterScenarioShowsHighVolumeInOther() {
        let s = makeState()
        s.selectDemoScenario(.overloadFilter)
        s.enterMode()

        XCTAssertEqual(s.categories[s.activeCategoryIndex], .other)

        let otherCount = s.countByCategory(.other)
        XCTAssertGreaterThanOrEqual(otherCount, 10)
        XCTAssertGreaterThan(otherCount, s.countByCategory(.urgent))
        XCTAssertGreaterThan(otherCount, s.countByCategory(.personal))
        XCTAssertGreaterThan(otherCount, s.countByCategory(.work))
    }

    func testScenarioMessageSetIsDeterministic() {
        XCTAssertEqual(DemoScenario.bankFraud.messages, DemoScenario.bankFraud.messages)
        XCTAssertEqual(DemoScenario.momBirthday.messages, DemoScenario.momBirthday.messages)
        XCTAssertEqual(DemoScenario.overloadFilter.messages, DemoScenario.overloadFilter.messages)
    }
}
