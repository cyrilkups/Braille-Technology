import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Full-screen Braille chord input view with 6 large touch zones.
/// Left column: dots 1, 2, 3
/// Right column: dots 4, 5, 6
public struct BrailleChordInputView: View {
    @EnvironmentObject var state: AppState

    @State private var activeDots: Set<Int> = []
    @State private var isTouching: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left column: dots 1, 2, 3
                VStack(spacing: 0) {
                    chordZone(dotIndex: 0, label: "1")
                    chordZone(dotIndex: 1, label: "2")
                    chordZone(dotIndex: 2, label: "3")
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(width: 2)
                    .background(Color.white.opacity(0.2))

                // Right column: dots 4, 5, 6
                VStack(spacing: 0) {
                    chordZone(dotIndex: 3, label: "4")
                    chordZone(dotIndex: 4, label: "5")
                    chordZone(dotIndex: 5, label: "6")
                }
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea()

            // Draft display overlay
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("reply")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        if state.currentDraft.isEmpty {
                            Text("(empty)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.3))
                        } else {
                            Text(state.currentDraft)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("dots:")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(
                            activeDots.isEmpty
                                ? "—" : activeDots.sorted().map(String.init).joined(separator: " ")
                        )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .padding(16)

                Spacer()

                // Bottom info
                HStack {
                    Text("Release to commit")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(activeDots.isEmpty ? "ready" : "holding")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(activeDots.isEmpty ? .green : .cyan)
                }
                .padding(12)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .padding(16)
            }
        }
        #if canImport(UIKit)
            .background(
                ChordTouchTracker(activeDots: $activeDots, onRelease: commitChord)
            )
        #endif
    }

    // MARK: - Zone rendering

    private func chordZone(dotIndex: Int, label: String) -> some View {
        let isActive = activeDots.contains(dotIndex)

        return ZStack {
            // Background
            Rectangle()
                .fill(
                    isActive
                        ? Color.white.opacity(0.15)
                        : Color.black
                )
                .border(
                    isActive ? Color.white.opacity(0.4) : Color.white.opacity(0.1),
                    width: 1
                )

            // Center circle indicator
            Circle()
                .fill(isActive ? Color.white : Color.white.opacity(0.2))
                .frame(width: 120, height: 120)

            // Label
            if state.judgeMode {
                VStack {
                    Spacer()
                    Text("Dot \(label)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isActive ? .black : .white.opacity(0.3))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Commit

    private func commitChord() {
        guard !activeDots.isEmpty else { return }

        let dotMask = activeDots.reduce(0) { mask, dot in
            mask | (1 << dot)
        }

        state.commitChordChar(dotMask: dotMask)

        // Play haptic feedback for valid commit
        state.haptics.play(.sendSuccess)

        // Clear active dots
        activeDots.removeAll()
    }
}

// MARK: - Touch tracker

#if canImport(UIKit)
    struct ChordTouchTracker: UIViewRepresentable {
        @Binding var activeDots: Set<Int>
        var onRelease: () -> Void

        func makeUIView(context: Context) -> ChordTouchView {
            let view = ChordTouchView()
            view.updateActiveDots = { dots in
                activeDots = dots
            }
            view.onRelease = onRelease
            return view
        }

        func updateUIView(_ uiView: ChordTouchView, context: Context) {}
    }

    class ChordTouchView: UIView {
        var updateActiveDots: ((Set<Int>) -> Void)?
        var onRelease: (() -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            processActiveDots(from: event)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesMoved(touches, with: event)
            processActiveDots(from: event)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            processActiveDots(from: event)

            // All touches lifted
            if event?.touches(for: self)?.isEmpty ?? true {
                onRelease?()
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            self.updateActiveDots?(Set<Int>())
        }

        private func processActiveDots(from event: UIEvent?) {
            guard let allTouches = event?.touches(for: self) else { return }

            var dots: Set<Int> = []

            for touch in allTouches {
                let location = touch.location(in: self)
                if let dotIndex = dotIndexForLocation(location) {
                    dots.insert(dotIndex)
                }
            }

            DispatchQueue.main.async {
                self.updateActiveDots?(dots)
            }
        }

        private func dotIndexForLocation(_ location: CGPoint) -> Int? {
            let width = bounds.width
            let height = bounds.height
            let isLeftHalf = location.x < width / 2
            let dotIndexInColumn = Int(location.y / (height / 3))

            guard (0..<3).contains(dotIndexInColumn) else { return nil }

            if isLeftHalf {
                return dotIndexInColumn  // 0, 1, 2
            } else {
                return dotIndexInColumn + 3  // 3, 4, 5
            }
        }
    }
#endif
