import Foundation

public enum HapticEvent: CaseIterable, Equatable {
    case categorySwitch
    case sendSuccess
    case sendFailure
    case endOfCategory
    case urgentQueuedAlert
    case enterFullMode
    case focusChanged
    case preview
    case activate
    case urgentTriplePulse
    case freezeConfirm
}

/// Deterministic dot-density-to-haptic-parameter mapping.
public enum TactileDensity {
    public static func tickIntensity(dotCount: Int) -> Float {
        let dc = Float(clamped06(dotCount))
        return min(max(0.15 + 0.12 * dc, 0.15), 1.0)
    }

    public static func bedIntensity(dotCount: Int) -> Float {
        let dc = Float(clamped06(dotCount))
        return min(max(0.05 + 0.10 * dc, 0.05), 0.8)
    }

    public static func bedSharpness(dotCount: Int) -> Float {
        let dc = Float(clamped06(dotCount))
        return min(max(0.20 + 0.10 * dc, 0.20), 1.0)
    }

    private static func clamped06(_ v: Int) -> Int { max(0, min(v, 6)) }
}

public protocol HapticService {
    mutating func play(_ event: HapticEvent)
    mutating func startTactileReading(signature: HapticSignature)
    mutating func updateTactileReading(dotCount: Int)
    mutating func stopTactileReading()
}

public extension HapticService {
    mutating func startTactileReading() {
        startTactileReading(signature: .neutral)
    }
}

public struct NoOpHapticService: HapticService {
    public init() {}
    public func play(_ event: HapticEvent) {}
    public func startTactileReading(signature: HapticSignature) {}
    public func updateTactileReading(dotCount: Int) {}
    public func stopTactileReading() {}
}

struct SpyHapticService: HapticService {
    private(set) var playedEvents: [HapticEvent] = []
    private(set) var tactileReadingStartCount: Int = 0
    private(set) var tactileReadingStartSignatures: [HapticSignature] = []
    private(set) var tactileReadingStopCount: Int = 0
    private(set) var tactileReadingDotCounts: [Int] = []

    mutating func play(_ event: HapticEvent) {
        playedEvents.append(event)
    }

    mutating func startTactileReading(signature: HapticSignature) {
        tactileReadingStartCount += 1
        tactileReadingStartSignatures.append(signature)
    }

    mutating func updateTactileReading(dotCount: Int) {
        tactileReadingDotCounts.append(dotCount)
    }

    mutating func stopTactileReading() {
        tactileReadingStopCount += 1
    }
}
