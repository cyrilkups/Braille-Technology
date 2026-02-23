import XCTest
@testable import SenseLayer

final class BrailleMappingTests: XCTestCase {

    typealias D = BrailleDot

    // MARK: - a–j (first decade)

    func testA() { XCTAssertEqual(BrailleMapping.map(D.dot1), "a") }
    func testB() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2), "b") }
    func testC() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot4), "c") }
    func testD() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot4 | D.dot5), "d") }
    func testE() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot5), "e") }
    func testF() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2 | D.dot4), "f") }
    func testG() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2 | D.dot4 | D.dot5), "g") }
    func testH() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2 | D.dot5), "h") }
    func testI() { XCTAssertEqual(BrailleMapping.map(D.dot2 | D.dot4), "i") }
    func testJ() { XCTAssertEqual(BrailleMapping.map(D.dot2 | D.dot4 | D.dot5), "j") }

    // MARK: - k–t (second decade, adds dot3)

    func testK() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot3), "k") }
    func testL() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2 | D.dot3), "l") }
    func testM() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot3 | D.dot4), "m") }
    func testN() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot3 | D.dot4 | D.dot5), "n") }
    func testO() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot3 | D.dot5), "o") }
    func testP() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2 | D.dot3 | D.dot4), "p") }
    func testQ() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2 | D.dot3 | D.dot4 | D.dot5), "q") }
    func testR() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2 | D.dot3 | D.dot5), "r") }
    func testS() { XCTAssertEqual(BrailleMapping.map(D.dot2 | D.dot3 | D.dot4), "s") }
    func testT() { XCTAssertEqual(BrailleMapping.map(D.dot2 | D.dot3 | D.dot4 | D.dot5), "t") }

    // MARK: - u–z (third decade, adds dot6)

    func testU() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot3 | D.dot6), "u") }
    func testV() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot2 | D.dot3 | D.dot6), "v") }
    func testW() { XCTAssertEqual(BrailleMapping.map(D.dot2 | D.dot4 | D.dot5 | D.dot6), "w") }
    func testX() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot3 | D.dot4 | D.dot6), "x") }
    func testY() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot3 | D.dot4 | D.dot5 | D.dot6), "y") }
    func testZ() { XCTAssertEqual(BrailleMapping.map(D.dot1 | D.dot3 | D.dot5 | D.dot6), "z") }

    // MARK: - Special constants

    func testSpaceConstant() {
        XCTAssertEqual(BrailleMapping.space, 0)
    }

    func testBackspaceConstant() {
        XCTAssertEqual(BrailleMapping.backspace, 63)
    }

    // MARK: - Unmapped bitmask returns nil

    func testUnmappedReturnsNil() {
        XCTAssertNil(BrailleMapping.map(D.dot6))
    }

    func testSpaceBitmaskReturnsNil() {
        XCTAssertNil(BrailleMapping.map(BrailleMapping.space))
    }

    // MARK: - Dot position values

    func testDotPositions() {
        XCTAssertEqual(D.dot1, 1)
        XCTAssertEqual(D.dot2, 2)
        XCTAssertEqual(D.dot3, 4)
        XCTAssertEqual(D.dot4, 8)
        XCTAssertEqual(D.dot5, 16)
        XCTAssertEqual(D.dot6, 32)
    }

    // MARK: - All 26 letters mapped

    func testTwentySixLettersMapped() {
        let alphabet = "abcdefghijklmnopqrstuvwxyz"
        let mapped = (0..<64).compactMap { BrailleMapping.map($0) }
        for letter in alphabet {
            XCTAssertTrue(mapped.contains(letter), "Missing mapping for '\(letter)'")
        }
    }
}
