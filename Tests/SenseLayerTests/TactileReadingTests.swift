import XCTest
@preconcurrency @testable import SenseLayer

final class TactileReadingTests: XCTestCase {

    // MARK: - TactileDensity mapping

    func testTickIntensityAtZeroDots() {
        let i = TactileDensity.tickIntensity(dotCount: 0)
        XCTAssertEqual(i, 0.15, accuracy: 0.001)
    }

    func testTickIntensityAtSixDots() {
        let i = TactileDensity.tickIntensity(dotCount: 6)
        XCTAssertEqual(i, 0.87, accuracy: 0.001)
    }

    func testTickIntensityAtThreeDots() {
        let i = TactileDensity.tickIntensity(dotCount: 3)
        XCTAssertEqual(i, 0.51, accuracy: 0.001)
    }

    func testTickIntensityClampsBelowZero() {
        let i = TactileDensity.tickIntensity(dotCount: -5)
        XCTAssertEqual(i, 0.15, accuracy: 0.001)
    }

    func testTickIntensityClampsAboveSix() {
        let i = TactileDensity.tickIntensity(dotCount: 100)
        XCTAssertEqual(i, 0.87, accuracy: 0.001)
    }

    func testBedIntensityAtZeroDots() {
        let i = TactileDensity.bedIntensity(dotCount: 0)
        XCTAssertEqual(i, 0.05, accuracy: 0.001)
    }

    func testBedIntensityAtSixDots() {
        let i = TactileDensity.bedIntensity(dotCount: 6)
        XCTAssertEqual(i, 0.65, accuracy: 0.001)
    }

    func testBedSharpnessAtZeroDots() {
        let s = TactileDensity.bedSharpness(dotCount: 0)
        XCTAssertEqual(s, 0.20, accuracy: 0.001)
    }

    func testBedSharpnessAtSixDots() {
        let s = TactileDensity.bedSharpness(dotCount: 6)
        XCTAssertEqual(s, 0.80, accuracy: 0.001)
    }

    func testIntensityMonotonicallyIncreases() {
        var prev: Float = -1
        for dc in 0...6 {
            let i = TactileDensity.tickIntensity(dotCount: dc)
            XCTAssertGreaterThanOrEqual(i, prev, "Intensity should not decrease at dotCount \(dc)")
            prev = i
        }
    }

    // MARK: - Spy tactile reading lifecycle

    func testSpyRecordsStartUpdateStop() {
        var spy = SpyHapticService()

        spy.startTactileReading()
        spy.updateTactileReading(dotCount: 3)
        spy.updateTactileReading(dotCount: 5)
        spy.stopTactileReading()

        XCTAssertEqual(spy.tactileReadingStartCount, 1)
        XCTAssertEqual(spy.tactileReadingStartSignatures, [.neutral])
        XCTAssertEqual(spy.tactileReadingDotCounts, [3, 5])
        XCTAssertEqual(spy.tactileReadingStopCount, 1)
    }

    func testSpyTactileStartsClean() {
        let spy = SpyHapticService()
        XCTAssertEqual(spy.tactileReadingStartCount, 0)
        XCTAssertTrue(spy.tactileReadingStartSignatures.isEmpty)
        XCTAssertTrue(spy.tactileReadingDotCounts.isEmpty)
        XCTAssertEqual(spy.tactileReadingStopCount, 0)
    }

    func testSpyMultipleSessions() {
        var spy = SpyHapticService()

        spy.startTactileReading()
        spy.updateTactileReading(dotCount: 1)
        spy.stopTactileReading()

        spy.startTactileReading()
        spy.updateTactileReading(dotCount: 6)
        spy.stopTactileReading()

        XCTAssertEqual(spy.tactileReadingStartCount, 2)
        XCTAssertEqual(spy.tactileReadingStartSignatures, [.neutral, .neutral])
        XCTAssertEqual(spy.tactileReadingDotCounts, [1, 6])
        XCTAssertEqual(spy.tactileReadingStopCount, 2)
    }

    // MARK: - SenseLayerState bridge

    func testStateDelegatesTactileReadingToHaptics() {
        let repo = InMemoryMessageRepository(seed: 1, count: 5)
        let s = SenseLayerState(repo: repo, haptics: SpyHapticService())
        s.enterMode()

        let startsBefore = s.haptics.tactileReadingStartCount
        s.beginTactileReading()
        XCTAssertEqual(s.haptics.tactileReadingStartCount, startsBefore + 1)
        XCTAssertEqual(s.haptics.tactileReadingStartSignatures.last, .neutral)

        s.updateTactileReading(dotCount: 4)
        XCTAssertEqual(s.haptics.tactileReadingDotCounts.last, 4)

        let stopsBefore = s.haptics.tactileReadingStopCount
        s.stopTactileReading()
        XCTAssertEqual(s.haptics.tactileReadingStopCount, stopsBefore + 1)
    }

    func testStateUsesReadContextSignatureForTactileReading() {
        let repo = InMemoryMessageRepository(seed: 1, count: 5)
        let s = SenseLayerState(repo: repo, haptics: SpyHapticService())
        s.enterMode()

        let message = Message.clamped(
            senderName: "Sam",
            body: "Need this now",
            urgencyScore: 0.9,
            tone: .anger,
            category: .urgent
        )
        let readCtx = ReadContext(message: message, appName: "Messages", hapticSignature: .empathy)
        s.enterReadMode(readCtx)

        s.beginTactileReading()
        XCTAssertEqual(s.haptics.tactileReadingStartSignatures.last, .empathy)
    }

    // MARK: - Cell index from drag offset

    func testDotCountChangesAcrossString() {
        let text = "a q"
        // 'a' = 1 dot, ' ' = 0 dots, 'q' = 5 dots
        let cells = BrailleCellMapper.cells(for: text)
        XCTAssertEqual(cells.count, 3)

        XCTAssertEqual(cells[0].raisedCount, 1) // 'a'
        XCTAssertEqual(cells[1].raisedCount, 0) // ' '
        XCTAssertEqual(cells[2].raisedCount, 5) // 'q'
    }

    func testCellIndexFromOffsetBoundaries() {
        let totalCells = 10

        let atStart = cellIndex(offset: 0.0, totalCells: totalCells)
        XCTAssertEqual(atStart, 0)

        let atEnd = cellIndex(offset: 1.0, totalCells: totalCells)
        XCTAssertEqual(atEnd, totalCells - 1)

        let atMid = cellIndex(offset: 0.5, totalCells: totalCells)
        XCTAssertEqual(atMid, 5)
    }

    func testCellIndexEmptyString() {
        let idx = cellIndex(offset: 0.5, totalCells: 0)
        XCTAssertEqual(idx, 0)
    }

    func testSimulatedDragProducesDifferentDotCounts() {
        let text = "hello world braille access"
        let cells = BrailleCellMapper.cells(for: text)

        var dotCounts: [Int] = []
        for step in stride(from: 0.0, through: 1.0, by: 0.1) {
            let idx = cellIndex(offset: step, totalCells: cells.count)
            dotCounts.append(cells[idx].raisedCount)
        }

        let unique = Set(dotCounts)
        XCTAssertGreaterThan(unique.count, 1, "Different positions should produce different dot counts")
    }

    // MARK: - popcount / raisedCount correctness

    func testPopcountOneDotMask() {
        // 'a' = dot1 only → bitmask 0b000001
        let cell = BrailleCell(bitmask: 0b000001)
        XCTAssertEqual(cell.raisedCount, 1)
    }

    func testPopcountThreeDotMask() {
        // 'l' = dots 1,2,3 → bitmask 0b000111
        let cell = BrailleCell(bitmask: 0b000111)
        XCTAssertEqual(cell.raisedCount, 3)
    }

    func testPopcountSixDotMask() {
        // All dots raised → bitmask 0b111111
        let cell = BrailleCell(bitmask: 0b111111)
        XCTAssertEqual(cell.raisedCount, 6)
    }

    func testPopcountZeroDotMask() {
        let cell = BrailleCell(bitmask: 0)
        XCTAssertEqual(cell.raisedCount, 0)
    }

    // MARK: - xNorm → cellIndex clamping

    func testCellIndexClampsNegativeOffset() {
        let idx = cellIndex(offset: -0.5, totalCells: 10)
        XCTAssertEqual(idx, 0, "Negative offset should clamp to first cell")
    }

    func testCellIndexClampsOverOneOffset() {
        let idx = cellIndex(offset: 1.5, totalCells: 10)
        XCTAssertEqual(idx, 9, "Offset > 1.0 should clamp to last cell")
    }

    func testCellIndexAtExactBoundaries() {
        XCTAssertEqual(cellIndex(offset: 0.0, totalCells: 5), 0)
        XCTAssertEqual(cellIndex(offset: 0.99, totalCells: 5), 4)
        XCTAssertEqual(cellIndex(offset: 1.0, totalCells: 5), 4)
    }

    func testCellIndexSingleCell() {
        XCTAssertEqual(cellIndex(offset: 0.0, totalCells: 1), 0)
        XCTAssertEqual(cellIndex(offset: 0.5, totalCells: 1), 0)
        XCTAssertEqual(cellIndex(offset: 1.0, totalCells: 1), 0)
    }

    #if canImport(UIKit)
    // MARK: - TactileEngine per-dot intensity

    func testDotIntensityTopRowIsStrongest() {
        let top = TactileEngine.dotIntensity(for: 0)
        let mid = TactileEngine.dotIntensity(for: 1)
        let bot = TactileEngine.dotIntensity(for: 2)
        XCTAssertGreaterThan(top, mid)
        XCTAssertGreaterThan(mid, bot)
    }

    func testDotIntensitySymmetricAcrossColumns() {
        XCTAssertEqual(TactileEngine.dotIntensity(for: 0), TactileEngine.dotIntensity(for: 3))
        XCTAssertEqual(TactileEngine.dotIntensity(for: 1), TactileEngine.dotIntensity(for: 4))
        XCTAssertEqual(TactileEngine.dotIntensity(for: 2), TactileEngine.dotIntensity(for: 5))
    }

    func testDotIntensityExpectedValues() {
        XCTAssertEqual(TactileEngine.dotIntensity(for: 0), 1.0, accuracy: 0.001)
        XCTAssertEqual(TactileEngine.dotIntensity(for: 1), 0.80, accuracy: 0.001)
        XCTAssertEqual(TactileEngine.dotIntensity(for: 2), 0.60, accuracy: 0.001)
    }

    func testEmptyPulseIntervalIsSix() {
        XCTAssertEqual(TactileEngine.emptyPulseInterval, 6)
    }

    func testTactileZoneEquality() {
        XCTAssertEqual(TactileZone.content, TactileZone.content)
        XCTAssertEqual(TactileZone.empty, TactileZone.empty)
        XCTAssertNotEqual(TactileZone.content, TactileZone.empty)
    }
    #endif

    // MARK: - BrailleCell bitmask round-trip

    func testBitmaskRoundTrip() {
        for mask in 0...63 {
            let cell = BrailleCell(bitmask: mask)
            XCTAssertEqual(cell.bitmask, mask, "Bitmask round-trip failed for \(mask)")
        }
    }

    func testSpaceCellBitmaskIsZero() {
        let cell = BrailleCellMapper.cell(for: " ")
        XCTAssertEqual(cell.bitmask, 0)
        XCTAssertEqual(cell.raisedCount, 0)
    }

    func testDistinctCharactersHaveDistinctBitmasks() {
        let a = BrailleCellMapper.cell(for: "a")
        let b = BrailleCellMapper.cell(for: "b")
        let l = BrailleCellMapper.cell(for: "l")
        XCTAssertNotEqual(a.bitmask, b.bitmask)
        XCTAssertNotEqual(b.bitmask, l.bitmask)
        XCTAssertNotEqual(a.bitmask, l.bitmask)
    }

    // Helper: mirrors the view's cell index computation
    private func cellIndex(offset: Double, totalCells: Int) -> Int {
        guard totalCells > 0 else { return 0 }
        let clamped = min(max(offset, 0), 1)
        return min(Int(clamped * Double(totalCells)), totalCells - 1)
    }
}
