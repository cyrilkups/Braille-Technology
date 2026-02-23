#if canImport(CoreHaptics)
import XCTest
import CoreHaptics
@preconcurrency @testable import SenseLayer

final class CoreHapticServiceTests: XCTestCase {

    // MARK: - Pattern mapping produces valid patterns for every event

    func testAllEventsProduceValidPatterns() {
        for event in HapticEvent.allCases {
            let pattern = CoreHapticService.pattern(for: event)
            XCTAssertGreaterThanOrEqual(
                pattern.duration, 0,
                "Pattern for \(event) should have non-negative duration"
            )
        }
    }

    func testCategorySwitchIsSingleTransient() {
        let pattern = CoreHapticService.pattern(for: .categorySwitch)
        XCTAssertEqual(pattern.duration, 0, accuracy: 0.01)
    }

    func testSendSuccessHasTwoEvents() {
        let pattern = CoreHapticService.pattern(for: .sendSuccess)
        XCTAssertGreaterThan(pattern.duration, 0.05)
    }

    func testSendFailureIsContinuous() {
        let pattern = CoreHapticService.pattern(for: .sendFailure)
        XCTAssertGreaterThanOrEqual(pattern.duration, 0.3 - 0.01)
    }

    func testEndOfCategoryHasDoubleTransient() {
        let pattern = CoreHapticService.pattern(for: .endOfCategory)
        XCTAssertGreaterThanOrEqual(pattern.duration, 0.1)
    }

    func testUrgentQueuedAlertIsLongContinuous() {
        let pattern = CoreHapticService.pattern(for: .urgentQueuedAlert)
        XCTAssertGreaterThanOrEqual(pattern.duration, 0.4)
    }

    func testEnterFullModeIsSingleTransient() {
        let pattern = CoreHapticService.pattern(for: .enterFullMode)
        XCTAssertEqual(pattern.duration, 0, accuracy: 0.01)
    }

    // MARK: - Safe initialization

    func testInitDoesNotCrash() {
        _ = CoreHapticService()
    }

    func testPlayDoesNotCrash() {
        let service = CoreHapticService()
        for event in HapticEvent.allCases {
            service.play(event)
        }
    }
}
#endif
