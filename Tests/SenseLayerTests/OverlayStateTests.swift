@preconcurrency @testable import SenseLayer
import XCTest

final class OverlayStateTests: XCTestCase {

    private func makeState() -> SenseLayerState<SpyHapticService> {
        let repo = InMemoryMessageRepository(seed: 1, count: 5)
        return SenseLayerState(repo: repo, haptics: SpyHapticService())
    }

    // MARK: - Focus navigation

    func testFocusStartsAtZero() {
        let s = makeState()
        s.enterMode()
        XCTAssertEqual(s.overlayFocusIndex, 0)
    }

    func testFocusNextIncrementsAndWraps() {
        let s = makeState()
        s.enterMode()
        let count = s.overlayMenuItems.count

        s.overlayFocusNext()
        XCTAssertEqual(s.overlayFocusIndex, 1)

        for _ in 1..<count {
            s.overlayFocusNext()
        }
        XCTAssertEqual(s.overlayFocusIndex, 0, "Should wrap around to 0")
    }

    func testFocusPrevDecrementsAndWraps() {
        let s = makeState()
        s.enterMode()

        s.overlayFocusPrev()
        XCTAssertEqual(
            s.overlayFocusIndex, s.overlayMenuItems.count - 1, "Should wrap to last item")
    }

    func testFocusChangeTriggersHaptic() {
        let s = makeState()
        s.enterMode()
        let eventsBefore = s.haptics.playedEvents.count

        s.overlayFocusNext()
        XCTAssertEqual(s.haptics.playedEvents.last, .categorySwitch)
        XCTAssertGreaterThan(s.haptics.playedEvents.count, eventsBefore)
    }

    // MARK: - Selection

    func testSelectCloseExitsMode() {
        let s = makeState()
        s.enterMode()
        XCTAssertTrue(s.isActive)

        // Navigate to Close (last item)
        let closeIndex = s.overlayMenuItems.firstIndex(of: .close)!
        for _ in 0..<closeIndex { s.overlayFocusNext() }
        XCTAssertEqual(s.overlayMenuItems[s.overlayFocusIndex], .close)

        s.overlaySelect()
        XCTAssertFalse(s.isActive)
    }

    func testSelectLaunchAppEntersNavigateMode() {
        let s = makeState()
        s.enterMode()
        XCTAssertEqual(s.currentMode, .home)

        // Focus should be on Launch App (index 0)
        XCTAssertEqual(s.overlayMenuItems[s.overlayFocusIndex], .launchApp)
        s.overlaySelect()

        // LaunchApp enters navigate mode for apps, not a sheet destination
        if case .navigate(let ctx) = s.currentMode {
            if case .apps = ctx {
                // Expected behavior
            } else {
                XCTFail("Should navigate to .apps context")
            }
        } else {
            XCTFail("Should be in navigate mode")
        }
    }

    func testSelectBrailleNotesSetsDestination() {
        let s = makeState()
        s.enterMode()

        let idx = s.overlayMenuItems.firstIndex(of: .brailleNotes)!
        for _ in 0..<idx { s.overlayFocusNext() }
        s.overlaySelect()
        XCTAssertEqual(s.overlayDestination, .brailleNotes)
    }

    func testSelectPreviewStripDoesNothing() {
        let s = makeState()
        s.enterMode()

        let idx = s.overlayMenuItems.firstIndex(of: .previewStrip)!
        for _ in 0..<idx { s.overlayFocusNext() }
        s.overlaySelect()
        XCTAssertNil(s.overlayDestination)
    }

    func testDismissDestination() {
        let s = makeState()
        s.enterMode()

        // Navigate to an item that sets destination (e.g., chooseItem)
        let chooseItemIdx = s.overlayMenuItems.firstIndex(of: .chooseItem)!
        for _ in 0..<chooseItemIdx { s.overlayFocusNext() }

        s.overlaySelect()  // opens chooseItem destination
        XCTAssertNotNil(s.overlayDestination)
        XCTAssertEqual(s.overlayDestination, .chooser)

        s.overlayDismissDestination()
        XCTAssertNil(s.overlayDestination)
    }

    // MARK: - Menu items

    func testMenuItemCount() {
        let s = makeState()
        XCTAssertEqual(s.overlayMenuItems.count, 7)
    }

    func testMenuItemOrder() {
        let s = makeState()
        XCTAssertEqual(
            s.overlayMenuItems,
            [
                .launchApp, .chooseItem, .brailleNotes, .brfFiles,
                .previewStrip, .liveCaptions, .close,
            ])
    }

    // MARK: - Preview strip tactile reading

    func testTactileReadingStartUpdateStop() {
        let s = makeState()
        s.enterMode()
        let startsBefore = s.haptics.tactileReadingStartCount
        let stopsBefore = s.haptics.tactileReadingStopCount

        s.beginTactileReading()
        XCTAssertEqual(s.haptics.tactileReadingStartCount, startsBefore + 1)
        XCTAssertEqual(s.haptics.tactileReadingStartSignatures.last, .neutral)

        s.updateTactileReading(dotCount: 4)
        XCTAssertEqual(s.haptics.tactileReadingDotCounts.last, 4)

        s.stopTactileReading()
        XCTAssertEqual(s.haptics.tactileReadingStopCount, stopsBefore + 1)
    }
}
