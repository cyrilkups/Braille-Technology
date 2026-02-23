import XCTest
@preconcurrency @testable import SenseLayer

private func makeTakeMeBackState() -> SenseLayerState<SpyHapticService> {
    let repo = InMemoryMessageRepository(seed: 1, count: 5)
    return SenseLayerState(repo: repo, haptics: SpyHapticService())
}

final class TakeMeBackTests: XCTestCase {

    func testTakeMeBackFromHomeExitsMode() {
        let s = makeTakeMeBackState()
        s.enterMode()

        s.takeMeBack()

        XCTAssertFalse(s.isActive)
        XCTAssertEqual(s.currentMode, .home)
    }

    func testTakeMeBackFromNavigateAppsReturnsHome() {
        let s = makeTakeMeBackState()
        s.enterMode()
        s.enterNavigateMode(.apps)

        s.takeMeBack()

        XCTAssertEqual(s.currentMode, .home)
        XCTAssertTrue(s.isActive)
    }

    func testTakeMeBackFromConversationsReturnsHome() {
        let s = makeTakeMeBackState()
        s.enterMode()
        s.enterNavigateMode(.conversations(appID: "Messages"))

        s.takeMeBack()

        XCTAssertEqual(s.currentMode, .home)
    }

    func testTakeMeBackFromReadWithAppReturnsConversations() {
        let s = makeTakeMeBackState()
        s.enterMode()

        let msg = Message.clamped(
            senderName: "A",
            body: "hello",
            urgencyScore: 0.5,
            tone: .calm,
            category: .other
        )
        s.enterReadMode(ReadContext(message: msg, appName: "Messages"))

        s.takeMeBack()

        XCTAssertEqual(s.currentMode, .navigate(context: .conversations(appID: "Messages")))
    }

    func testTakeMeBackFromReadWithoutAppReturnsHome() {
        let s = makeTakeMeBackState()
        s.enterMode()

        let msg = Message.clamped(
            senderName: "A",
            body: "hello",
            urgencyScore: 0.5,
            tone: .calm,
            category: .other
        )
        s.enterReadMode(ReadContext(message: msg, appName: nil))

        s.takeMeBack()

        XCTAssertEqual(s.currentMode, .home)
    }
}
