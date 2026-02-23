import XCTest
@testable import SenseLayer

final class HapticServiceTests: XCTestCase {

    // MARK: - SpyHapticService records events

    func testSpyRecordsSingleEvent() {
        var spy = SpyHapticService()
        spy.play(.sendSuccess)
        XCTAssertEqual(spy.playedEvents, [.sendSuccess])
    }

    func testSpyRecordsMultipleEventsInOrder() {
        var spy = SpyHapticService()
        spy.play(.categorySwitch)
        spy.play(.urgentQueuedAlert)
        spy.play(.sendFailure)
        spy.play(.endOfCategory)
        XCTAssertEqual(spy.playedEvents, [
            .categorySwitch,
            .urgentQueuedAlert,
            .sendFailure,
            .endOfCategory
        ])
    }

    func testSpyStartsEmpty() {
        let spy = SpyHapticService()
        XCTAssertTrue(spy.playedEvents.isEmpty)
    }

    func testSpyRecordsDuplicates() {
        var spy = SpyHapticService()
        spy.play(.enterFullMode)
        spy.play(.enterFullMode)
        XCTAssertEqual(spy.playedEvents.count, 2)
        XCTAssertEqual(spy.playedEvents, [.enterFullMode, .enterFullMode])
    }

    func testSpyRecordsTactileStartSignature() {
        var spy = SpyHapticService()
        spy.startTactileReading(signature: .urgent)
        XCTAssertEqual(spy.tactileReadingStartSignatures, [.urgent])
    }

    // MARK: - NoOpHapticService

    func testNoOpDoesNotCrash() {
        let noop = NoOpHapticService()
        for event in HapticEvent.allCases {
            noop.play(event)
        }
    }

    // MARK: - HapticEvent cases

    func testHapticEventCaseCount() {
        XCTAssertEqual(HapticEvent.allCases.count, 11)
    }
}
