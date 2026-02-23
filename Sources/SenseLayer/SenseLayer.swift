import Foundation

// MARK: - SenseLayer MVP
//
// SenseLayer is a tactile-first messaging app for deafblind users.
//
// Architecture overview:
//   Models/    – Pure-Swift domain types (Message, MessageCategory, Tone).
//   Services/  – Rule-based message compression: category, tone, urgency score, 1-line summary.
//   State/     – Observable app state (inbox, navigation, selection).
//   Views/     – SwiftUI screens (demo-only visuals):
//                • Category inbox (grouped, sorted by urgency)
//                • "Braille strip" reading view (horizontal drag windowing)
//                • 6-dot braille keyboard (sequential + chorded input)
//   Haptics/   – CoreHaptics feedback (success/failure/end-of-category) with NoOp fallback.
//   Utilities/ – Shared helpers (formatters, extensions).
//
// Design constraints:
//   • Zero audio reliance — all feedback is haptic.
//   • Visuals exist solely for sighted demo observers.
//   • urgencyScore is always clamped to 0…1.
//   • All model types conform to Equatable & Hashable.

/// Namespace for the SenseLayer module.
public enum SenseLayer {
    public static let version = "0.1.0"
}
