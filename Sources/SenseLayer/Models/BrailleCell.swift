import Foundation

/// A single 6-dot braille cell. Each dot is either raised or flat.
///
///     Layout:  d1 d4
///              d2 d5
///              d3 d6
public struct BrailleCell: Equatable, Hashable, Sendable {
    public let dots: [Bool] // length 6, indexed 0…5 → dot1…dot6

    public init(dots: [Bool]) {
        precondition(dots.count == 6)
        self.dots = dots
    }

    public init(bitmask: Int) {
        self.dots = (0..<6).map { (bitmask >> $0) & 1 == 1 }
    }

    public var raisedCount: Int { dots.filter { $0 }.count }

    /// Reconstruct the 6-bit bitmask from the dot array.
    public var bitmask: Int {
        dots.enumerated().reduce(0) { $0 | ($1.element ? (1 << $1.offset) : 0) }
    }

    public static let blank = BrailleCell(bitmask: 0)
}

/// Converts characters to `BrailleCell` using Grade 1 braille mapping.
public enum BrailleCellMapper {

    private static let charToMask: [Character: Int] = {
        let d1 = BrailleDot.dot1, d2 = BrailleDot.dot2, d3 = BrailleDot.dot3
        let d4 = BrailleDot.dot4, d5 = BrailleDot.dot5, d6 = BrailleDot.dot6
        return [
            "a": d1,
            "b": d1|d2,
            "c": d1|d4,
            "d": d1|d4|d5,
            "e": d1|d5,
            "f": d1|d2|d4,
            "g": d1|d2|d4|d5,
            "h": d1|d2|d5,
            "i": d2|d4,
            "j": d2|d4|d5,
            "k": d1|d3,
            "l": d1|d2|d3,
            "m": d1|d3|d4,
            "n": d1|d3|d4|d5,
            "o": d1|d3|d5,
            "p": d1|d2|d3|d4,
            "q": d1|d2|d3|d4|d5,
            "r": d1|d2|d3|d5,
            "s": d2|d3|d4,
            "t": d2|d3|d4|d5,
            "u": d1|d3|d6,
            "v": d1|d2|d3|d6,
            "w": d2|d4|d5|d6,
            "x": d1|d3|d4|d6,
            "y": d1|d3|d4|d5|d6,
            "z": d1|d3|d5|d6,
            " ": 0,
        ]
    }()

    /// Convert a single character to a BrailleCell (lowercased). Unknown chars become blank.
    public static func cell(for char: Character) -> BrailleCell {
        let lower = Character(char.lowercased())
        guard let mask = charToMask[lower] else { return .blank }
        return BrailleCell(bitmask: mask)
    }

    /// Convert a string to an array of BrailleCells.
    public static func cells(for text: String) -> [BrailleCell] {
        text.map { cell(for: $0) }
    }

    /// Compute average dot density (0…1) for a string's braille representation.
    public static func dotDensity(for text: String) -> Float {
        let cells = cells(for: text)
        guard !cells.isEmpty else { return 0 }
        let totalRaised = cells.reduce(0) { $0 + $1.raisedCount }
        return Float(totalRaised) / Float(cells.count * 6)
    }
}
