import Foundation

public enum MessageCategory: CaseIterable, Equatable, Hashable {
    case urgent
    case personal
    case work
    case other
}
