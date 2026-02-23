import Foundation

/// Standard 6-dot braille cell positions as bitmasks.
///
///     Dot layout:    1 • • 4
///                    2 • • 5
///                    3 • • 6
enum BrailleDot {
    static let dot1 = 1 << 0  // 0b000001
    static let dot2 = 1 << 1  // 0b000010
    static let dot3 = 1 << 2  // 0b000100
    static let dot4 = 1 << 3  // 0b001000
    static let dot5 = 1 << 4  // 0b010000
    static let dot6 = 1 << 5  // 0b100000
}

/// Maps 6-dot braille bitmasks (0…63) to characters.
enum BrailleMapping {

    /// Space: all dots released (bitmask 0).
    static let space = 0

    /// Backspace: all six dots raised.
    static let backspace = 0b111111 // 63

    private static let table: [Int: Character] = {
        let d1 = BrailleDot.dot1
        let d2 = BrailleDot.dot2
        let d3 = BrailleDot.dot3
        let d4 = BrailleDot.dot4
        let d5 = BrailleDot.dot5
        let d6 = BrailleDot.dot6

        return [
            // Letters a–z  (Grade 1 / uncontracted braille)
            d1:                         "a",  // ⠁
            d1|d2:                      "b",  // ⠃
            d1|d4:                      "c",  // ⠉
            d1|d4|d5:                   "d",  // ⠙
            d1|d5:                      "e",  // ⠑
            d1|d2|d4:                   "f",  // ⠋
            d1|d2|d4|d5:               "g",  // ⠛
            d1|d2|d5:                   "h",  // ⠓
            d2|d4:                      "i",  // ⠊
            d2|d4|d5:                   "j",  // ⠚
            d1|d3:                      "k",  // ⠅
            d1|d2|d3:                   "l",  // ⠇
            d1|d3|d4:                   "m",  // ⠍
            d1|d3|d4|d5:               "n",  // ⠝
            d1|d3|d5:                   "o",  // ⠕
            d1|d2|d3|d4:               "p",  // ⠏
            d1|d2|d3|d4|d5:            "q",  // ⠟
            d1|d2|d3|d5:               "r",  // ⠗
            d2|d3|d4:                   "s",  // ⠎
            d2|d3|d4|d5:               "t",  // ⠞
            d1|d3|d6:                   "u",  // ⠥
            d1|d2|d3|d6:               "v",  // ⠧
            d2|d4|d5|d6:               "w",  // ⠺
            d1|d3|d4|d6:               "x",  // ⠭
            d1|d3|d4|d5|d6:            "y",  // ⠽
            d1|d3|d5|d6:               "z",  // ⠵
        ]
    }()

    /// Returns the character for a 6-dot bitmask, or `nil` if unmapped.
    static func map(_ bitmask: Int) -> Character? {
        table[bitmask]
    }
}
