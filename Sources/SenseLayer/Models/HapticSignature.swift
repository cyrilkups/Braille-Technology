import Foundation

/// Emotional/contextual signature for tactile feedback during message reading.
public enum HapticSignature: Equatable {
    case urgent
    case calm
    case empathy
    case anger
    case neutral

    /// Baseline energy for this signature, before dot-density blending.
    public var baselineIntensity: Double {
        switch self {
        case .urgent:
            return 0.85
        case .calm:
            return 0.25
        case .empathy:
            return 0.35
        case .anger:
            return 0.95
        case .neutral:
            return 0.5
        }
    }

    /// Baseline cadence in milliseconds.
    public var baselineTickIntervalMs: Double {
        switch self {
        case .urgent:
            return 20
        case .calm:
            return 45
        case .empathy:
            return 30
        case .anger:
            return 18
        case .neutral:
            return 33
        }
    }

    /// Baseline sharpness before dot-density blending.
    public var baselineSharpness: Double {
        switch self {
        case .urgent:
            return 0.95
        case .calm:
            return 0.18
        case .empathy:
            return 0.35
        case .anger:
            return 1.0
        case .neutral:
            return 0.45
        }
    }

    /// Per-tick baseline modulation used by tactile streaming.
    public struct BaselineFrame: Equatable {
        public let tickIsActive: Bool
        public let tickIntensityScale: Double
        public let bedIntensityScale: Double
        public let sharpnessScale: Double

        public init(
            tickIsActive: Bool,
            tickIntensityScale: Double,
            bedIntensityScale: Double,
            sharpnessScale: Double
        ) {
            self.tickIsActive = tickIsActive
            self.tickIntensityScale = tickIntensityScale
            self.bedIntensityScale = bedIntensityScale
            self.sharpnessScale = sharpnessScale
        }
    }

    /// Returns the modulation frame for a specific tick.
    public func baselineFrame(tickIndex: Int, elapsed: TimeInterval) -> BaselineFrame {
        switch self {
        case .urgent:
            // Fast + sharp with light accent every 4 ticks.
            let accent = (tickIndex % 4 == 0) ? 1.0 : 0.88
            return BaselineFrame(
                tickIsActive: true,
                tickIntensityScale: accent,
                bedIntensityScale: 0.92,
                sharpnessScale: 1.0
            )

        case .calm:
            // Soft + smooth.
            return BaselineFrame(
                tickIsActive: true,
                tickIntensityScale: 0.55,
                bedIntensityScale: 0.68,
                sharpnessScale: 0.65
            )

        case .empathy:
            // Gentle oscillation around a soft baseline.
            let wave = (sin(elapsed * .pi * 2.2) + 1.0) / 2.0  // 0...1
            return BaselineFrame(
                tickIsActive: true,
                tickIntensityScale: 0.60 + (0.25 * wave),
                bedIntensityScale: 0.60 + (0.25 * wave),
                sharpnessScale: 0.70 + (0.20 * wave)
            )

        case .anger:
            // Segmented harsh ticks in short aggressive bursts.
            let phase = tickIndex % 6
            let active = (phase == 0) || (phase == 1) || (phase == 3)
            return BaselineFrame(
                tickIsActive: active,
                tickIntensityScale: active ? 1.0 : 0.15,
                bedIntensityScale: active ? 1.0 : 0.05,
                sharpnessScale: 1.0
            )

        case .neutral:
            return BaselineFrame(
                tickIsActive: true,
                tickIntensityScale: 0.78,
                bedIntensityScale: 0.75,
                sharpnessScale: 0.85
            )
        }
    }

    /// Derive signature from message category or content
    public static func from(category: MessageCategory, urgency: Double = 0.5) -> HapticSignature {
        switch category {
        case .urgent:
            return .urgent
        case .work:
            return urgency > 0.7 ? .anger : .neutral
        case .personal:
            return .empathy
        case .other:
            return .calm
        }
    }
}
