import Foundation

/// Shared helpers and extensions for SenseLayer.
extension Date {
    /// Compact timestamp string for display.
    var shortTimestamp: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: self)
    }
}
