#if canImport(UIKit)
import Foundation
import UIKit

/// Which tactile zone the finger is currently in.
public enum TactileZone: Equatable {
    /// Over interactive braille content — crisp per-dot bursts.
    case content
    /// Over empty/non-interactive space — slow ambient pulse.
    case empty
}

/// Haptic engine for braille tactile reading with two distinct modes:
///
/// **Content zone** — When the finger is over braille dots, fires a distinct
/// burst of pulses for each cell. Each raised dot produces one pulse; intensity
/// and timing vary by dot position so every character has a unique fingerprint.
///
/// **Empty zone** — When the finger is over non-interactive space (gaps between
/// rows, margins), fires a soft ambient pulse at ~4Hz so the user always feels
/// "something" and knows the surface is alive. The contrast between crisp content
/// and soft ambient makes row boundaries obvious.
///
/// Transitioning between zones fires a medium-intensity boundary bump.
@MainActor
public final class TactileEngine: ObservableObject {

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var currentZone: TactileZone = .empty
    @Published public private(set) var currentCellIndex: Int = -1

    private let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let softGen = UIImpactFeedbackGenerator(style: .soft)

    private var pendingBurstItems: [DispatchWorkItem] = []
    private var emptyTimer: DispatchSourceTimer?
    private var emptyTickCount: Int = 0

    public init() {}

    deinit {
        emptyTimer?.cancel()
    }

    // MARK: - Public API

    public func start() {
        guard !isActive else { return }
        isActive = true
        currentCellIndex = -1
        currentZone = .empty
        rigidGen.prepare()
        mediumGen.prepare()
        lightGen.prepare()
        softGen.prepare()
    }

    /// Finger is over braille content. Fires a dot-pattern burst when
    /// `cellIndex` changes. Stops ambient pulse if transitioning from empty.
    public func updateContent(cellIndex: Int, bitmask: Int) {
        guard isActive else { return }
        if currentZone != .content {
            stopEmptyTimer()
            cancelPendingBurst()
            currentZone = .content
            mediumGen.impactOccurred(intensity: 0.65)
            mediumGen.prepare()
        }
        if cellIndex != currentCellIndex {
            currentCellIndex = cellIndex
            cancelPendingBurst()
            playDotPattern(bitmask: bitmask)
        }
    }

    /// Finger is over empty/non-interactive space. Starts slow ambient pulse.
    public func enterEmpty() {
        guard isActive else { return }
        if currentZone != .empty {
            cancelPendingBurst()
            currentCellIndex = -1
            currentZone = .empty
            mediumGen.impactOccurred(intensity: 0.65)
            mediumGen.prepare()
            startEmptyTimer()
        }
    }

    public func stop() {
        cancelPendingBurst()
        stopEmptyTimer()
        isActive = false
        currentCellIndex = -1
        currentZone = .empty
    }

    // MARK: - Content burst pattern

    private func playDotPattern(bitmask: Int) {
        guard bitmask != 0 else { return }

        let scanOrder = [0, 1, 2, 3, 4, 5]
        var delay: TimeInterval = 0
        let raisedGap: TimeInterval = 0.020
        let absentGap: TimeInterval = 0.010

        for dot in scanOrder {
            let isRaised = (bitmask >> dot) & 1 == 1
            if isRaised {
                let d = delay
                let dotIdx = dot
                let item = DispatchWorkItem { [weak self] in
                    self?.firePulse(dotIndex: dotIdx)
                }
                pendingBurstItems.append(item)
                DispatchQueue.main.asyncAfter(deadline: .now() + d, execute: item)
                delay += raisedGap
            } else {
                delay += absentGap
            }
        }
    }

    private func firePulse(dotIndex: Int) {
        switch dotIndex {
        case 0, 3:
            rigidGen.impactOccurred(intensity: 1.0)
            rigidGen.prepare()
        case 1, 4:
            mediumGen.impactOccurred(intensity: 0.80)
            mediumGen.prepare()
        case 2, 5:
            lightGen.impactOccurred(intensity: 0.60)
            lightGen.prepare()
        default:
            rigidGen.impactOccurred(intensity: 0.7)
            rigidGen.prepare()
        }
    }

    private func cancelPendingBurst() {
        for item in pendingBurstItems { item.cancel() }
        pendingBurstItems.removeAll()
    }

    // MARK: - Empty-zone ambient pulse (4Hz via 25Hz timer, fire every 6th tick)

    private func startEmptyTimer() {
        stopEmptyTimer()
        emptyTickCount = 0
        softGen.prepare()

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 0.04) // 25Hz base
        t.setEventHandler { [weak self] in
            Task { @MainActor in self?.emptyTick() }
        }
        t.resume()
        emptyTimer = t
    }

    private func emptyTick() {
        guard isActive, currentZone == .empty else {
            stopEmptyTimer()
            return
        }
        emptyTickCount += 1
        if emptyTickCount % 6 == 0 {
            softGen.impactOccurred(intensity: 0.20)
            softGen.prepare()
        }
    }

    private func stopEmptyTimer() {
        emptyTimer?.cancel()
        emptyTimer = nil
        emptyTickCount = 0
    }

    // MARK: - Test helpers

    public static func dotIntensity(for dotIndex: Int) -> Double {
        switch dotIndex {
        case 0, 3: return 1.0
        case 1, 4: return 0.80
        case 2, 5: return 0.60
        default: return 0.7
        }
    }

    /// Ambient pulse fires every Nth tick of the 25Hz base timer.
    public static let emptyPulseInterval: Int = 6
}
#endif
