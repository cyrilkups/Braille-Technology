import XCTest
@preconcurrency @testable import SenseLayer

/// Integration-style test: scripts a full user journey through the state machine
/// covering enter → read → full mode → reply → send → urgent queue → inactivity.
final class IntegrationTests: XCTestCase {

    private func makeIntegrationState(
        scheduler: TestScheduler = TestScheduler()
    ) -> (SenseLayerState<SpyHapticService>, TestScheduler) {
        let messages: [Message] = [
            Message.clamped(senderName: "Boss", body: "Critical deadline asap", urgencyScore: 0.9, tone: .urgent, category: .urgent),
            Message.clamped(senderName: "Bank", body: "Fraud detected on your account", urgencyScore: 0.95, tone: .urgent, category: .urgent),
            Message.clamped(senderName: "Mom", body: "Dinner at 7 love you", urgencyScore: 0.3, tone: .calm, category: .personal),
            Message.clamped(senderName: "Colleague", body: "Meeting at 3pm client review", urgencyScore: 0.5, tone: .calm, category: .work),
            Message.clamped(senderName: "Newsletter", body: "Weekly update from your feed", urgencyScore: 0.2, tone: .calm, category: .other),
        ]

        struct StubRepo: MessageRepository {
            var msgs: [Message]
            mutating func loadMessages() -> [Message] { msgs }
            mutating func markRead(id: UUID) {}
            func isRead(id: UUID) -> Bool { false }
        }

        let state = SenseLayerState(
            repo: StubRepo(msgs: messages),
            drafts: DraftStore(),
            sender: MockSendService(mode: .success),
            scheduler: scheduler,
            haptics: SpyHapticService()
        )
        return (state, scheduler)
    }

    // MARK: - Full scripted journey

    func testScriptedUserJourney() async {
        let (s, scheduler) = makeIntegrationState()

        // 1. Enter mode — starts at urgent category, message 0
        s.enterMode()
        XCTAssertTrue(s.isActive)
        XCTAssertEqual(s.categories[s.activeCategoryIndex], .urgent)
        XCTAssertEqual(s.activeMessageIndex, 0)
        XCTAssertEqual(s.currentMessage?.senderName, "Boss")
        XCTAssertEqual(s.readingMode, .summary)

        // 2. Enter full mode
        s.enterFullMode()
        XCTAssertEqual(s.readingMode, .full)
        XCTAssertEqual(s.haptics.playedEvents.last, .enterFullMode)

        // 3. Full mode persists after interaction
        s.registerInteraction()
        XCTAssertEqual(s.readingMode, .full)

        // 4. Exit full mode
        s.exitFullMode()
        XCTAssertEqual(s.readingMode, .summary)

        // 5. Advance to next message
        s.nextMessage()
        XCTAssertEqual(s.currentMessage?.senderName, "Bank")
        XCTAssertEqual(s.activeMessageIndex, 1)

        // 6. End of category — haptic fires, no advance
        s.nextMessage()
        XCTAssertEqual(s.activeMessageIndex, 1)
        XCTAssertEqual(s.haptics.playedEvents.last, .endOfCategory)

        // 7. Switch to personal category
        s.nextCategory()
        XCTAssertEqual(s.categories[s.activeCategoryIndex], .personal)
        XCTAssertEqual(s.activeMessageIndex, 0)
        XCTAssertEqual(s.currentMessage?.senderName, "Mom")
        XCTAssertEqual(s.haptics.playedEvents.last, .categorySwitch)

        // 8. Start reply — compose mode
        s.startReply()
        XCTAssertTrue(s.isComposing)
        XCTAssertEqual(s.currentDraft, "")

        // 9. Type via braille keyboard (simulated)
        s.appendCharacter("h")
        s.appendCharacter("i")
        XCTAssertEqual(s.currentDraft, "hi")

        // 10. Delete last char
        s.deleteLastChar()
        XCTAssertEqual(s.currentDraft, "h")

        // 11. Type more
        s.appendCharacter("e")
        s.appendCharacter("y")
        XCTAssertEqual(s.currentDraft, "hey")

        // 12. Send — success path
        await s.sendDraft()
        XCTAssertFalse(s.isComposing)
        XCTAssertEqual(s.currentDraft, "")
        XCTAssertEqual(s.lastSendResult, .sent)
        XCTAssertTrue(s.haptics.playedEvents.contains(.sendSuccess))

        // 13. Receive urgent message while reading — silent queue
        let urgentMsg = Message.clamped(
            senderName: "Security",
            body: "Suspicious login detected immediately",
            urgencyScore: 0.95,
            tone: .urgent,
            category: .urgent
        )
        let hapticCountBefore = s.haptics.playedEvents.count
        s.receiveNewMessage(urgentMsg)
        XCTAssertEqual(s.urgentQueue.count, 1)
        XCTAssertEqual(s.haptics.playedEvents.count, hapticCountBefore, "No immediate haptic on urgent receive")

        // 14. Exit category to dashboard — drains urgent queue
        s.exitCategoryToDashboard()
        XCTAssertEqual(s.urgentQueue.count, 0)
        XCTAssertEqual(s.haptics.playedEvents.last, .urgentQueuedAlert)

        // 15. Navigate to work category
        s.nextCategory()
        XCTAssertEqual(s.categories[s.activeCategoryIndex], .personal)
        s.nextCategory()
        XCTAssertEqual(s.categories[s.activeCategoryIndex], .work)
        XCTAssertEqual(s.currentMessage?.senderName, "Colleague")

        // 16. Start reply, type, then switch category — draft saved
        s.startReply()
        s.appendCharacter("o")
        s.appendCharacter("k")
        s.nextCategory() // switches to "other"
        XCTAssertFalse(s.isComposing)
        XCTAssertEqual(s.categories[s.activeCategoryIndex], .other)

        // 17. Go back to work and verify draft loaded
        s.prevCategory()
        XCTAssertEqual(s.categories[s.activeCategoryIndex], .work)
        s.startReply()
        XCTAssertEqual(s.currentDraft, "ok")

        // 18. Test send failure
        s.sender = MockSendService(mode: .failure)
        s.appendCharacter("!")
        await s.sendDraft()
        XCTAssertTrue(s.isComposing, "Should remain composing on failure")
        XCTAssertEqual(s.currentDraft, "ok!", "Draft preserved on failure")
        XCTAssertEqual(s.lastSendResult, .failed)
        XCTAssertTrue(s.haptics.playedEvents.contains(.sendFailure))

        // 19. Inactivity auto-exit saves draft
        scheduler.advance(by: 61)
        XCTAssertFalse(s.isActive)

        // 20. Re-enter and verify draft survives
        s.enterMode()
        // Navigate back to work
        s.nextCategory() // personal
        s.nextCategory() // work
        s.startReply()
        XCTAssertEqual(s.currentDraft, "ok!", "Draft persisted through inactivity exit")
    }

    // MARK: - Verify haptics sequence is consistent

    func testHapticsSequenceForBasicFlow() {
        let (s, _) = makeIntegrationState()
        s.enterMode()
        s.enterFullMode()
        s.exitFullMode()
        s.nextMessage()
        s.nextMessage() // end of category
        s.nextCategory()
        s.exitMode()

        let events = s.haptics.playedEvents
        XCTAssertEqual(events, [
            .enterFullMode,
            .endOfCategory,
            .categorySwitch,
        ])
    }
}
