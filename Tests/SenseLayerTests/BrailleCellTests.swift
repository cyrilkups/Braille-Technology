import XCTest
@testable import SenseLayer

final class BrailleCellTests: XCTestCase {

    // MARK: - BrailleCell

    func testBlankCellHasNoRaisedDots() {
        let cell = BrailleCell.blank
        XCTAssertEqual(cell.raisedCount, 0)
        XCTAssertEqual(cell.dots, [false, false, false, false, false, false])
    }

    func testCellFromBitmaskDot1() {
        let cell = BrailleCell(bitmask: BrailleDot.dot1)
        XCTAssertTrue(cell.dots[0])
        XCTAssertEqual(cell.raisedCount, 1)
    }

    func testCellFromBitmaskAllDots() {
        let cell = BrailleCell(bitmask: 0b111111)
        XCTAssertEqual(cell.raisedCount, 6)
        XCTAssertTrue(cell.dots.allSatisfy { $0 })
    }

    func testCellEquality() {
        let a = BrailleCell(bitmask: BrailleDot.dot1 | BrailleDot.dot2)
        let b = BrailleCell(bitmask: BrailleDot.dot1 | BrailleDot.dot2)
        XCTAssertEqual(a, b)
    }

    // MARK: - BrailleCellMapper

    func testMapperLetterA() {
        let cell = BrailleCellMapper.cell(for: "a")
        XCTAssertEqual(cell.raisedCount, 1)
        XCTAssertTrue(cell.dots[0]) // dot1
    }

    func testMapperLetterAUppercase() {
        let cell = BrailleCellMapper.cell(for: "A")
        XCTAssertEqual(cell, BrailleCellMapper.cell(for: "a"))
    }

    func testMapperSpace() {
        let cell = BrailleCellMapper.cell(for: " ")
        XCTAssertEqual(cell, BrailleCell.blank)
    }

    func testMapperUnknownCharIsBlank() {
        let cell = BrailleCellMapper.cell(for: "9")
        XCTAssertEqual(cell, BrailleCell.blank)
    }

    func testCellsForString() {
        let cells = BrailleCellMapper.cells(for: "ab")
        XCTAssertEqual(cells.count, 2)
        XCTAssertEqual(cells[0], BrailleCellMapper.cell(for: "a"))
        XCTAssertEqual(cells[1], BrailleCellMapper.cell(for: "b"))
    }

    func testDotDensityAllLetters() {
        let density = BrailleCellMapper.dotDensity(for: "abc")
        XCTAssertGreaterThan(density, 0)
        XCTAssertLessThanOrEqual(density, 1)
    }

    func testDotDensityAllSpaces() {
        let density = BrailleCellMapper.dotDensity(for: "   ")
        XCTAssertEqual(density, 0)
    }

    func testDotDensityEmpty() {
        let density = BrailleCellMapper.dotDensity(for: "")
        XCTAssertEqual(density, 0)
    }

    func testDotDensityDenseVsSparse() {
        let dense = BrailleCellMapper.dotDensity(for: "qqqq") // q has 5 dots
        let sparse = BrailleCellMapper.dotDensity(for: "aaaa") // a has 1 dot
        XCTAssertGreaterThan(dense, sparse)
    }
}
