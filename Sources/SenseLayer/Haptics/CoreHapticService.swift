#if canImport(CoreHaptics)
    import CoreHaptics
    import Foundation
    #if canImport(UIKit)
        import UIKit
    #endif

    /// Two-layer haptic engine:
    ///   Layer A — UIImpactFeedbackGenerator ticks at signature-defined cadence
    ///   Layer B — CoreHaptics continuous bed with smooth parameter updates (enhancement)
    ///   Signature layer — Baseline pattern that conveys emotional context
    public final class CoreHapticService: HapticService, @unchecked Sendable {

        private var engine: CHHapticEngine?

        // Tactile reading — Layer A
        #if canImport(UIKit)
            private var impactGenerator: UIImpactFeedbackGenerator?
        #endif
        private var tickTimer: DispatchSourceTimer?
        private var currentDotCount: Int = 0
        private var currentSignature: HapticSignature = .neutral
        private var tickIndex: Int = 0
        private var readingStartUptime: TimeInterval = 0
        private var movementBoostTicksRemaining: Int = 0

        // Tactile reading — Layer B
        private var bedPlayer: CHHapticAdvancedPatternPlayer?

        public init() {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            do {
                let eng = try CHHapticEngine()
                eng.isAutoShutdownEnabled = true
                eng.resetHandler = { [weak self] in
                    try? self?.engine?.start()
                }
                try eng.start()
                engine = eng
            } catch {
                engine = nil
            }
        }

        deinit {
            tickTimer?.cancel()
        }

        // MARK: - Discrete events

        public func play(_ event: HapticEvent) {
            guard let engine else { return }
            do {
                let player = try engine.makePlayer(with: Self.pattern(for: event))
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {}
        }

        // MARK: - Two-layer tactile reading session

        public func startTactileReading(signature: HapticSignature) {
            tickTimer?.cancel()
            tickTimer = nil
            do { try bedPlayer?.stop(atTime: CHHapticTimeImmediate) } catch {}
            bedPlayer = nil

            currentDotCount = 0
            currentSignature = signature
            tickIndex = 0
            readingStartUptime = ProcessInfo.processInfo.systemUptime
            movementBoostTicksRemaining = 0

            #if canImport(UIKit)
                MainActor.assumeIsolated {
                    let gen = UIImpactFeedbackGenerator(style: .rigid)
                    gen.prepare()
                    impactGenerator = gen
                }
            #endif

            if let engine {
                do {
                    let pattern = try CHHapticPattern(
                        events: [
                            CHHapticEvent(
                                eventType: .hapticContinuous,
                                parameters: [
                                    CHHapticEventParameter(
                                        parameterID: .hapticIntensity,
                                        value: Float(signature.baselineIntensity * 0.20)),
                                    CHHapticEventParameter(
                                        parameterID: .hapticSharpness,
                                        value: Float(signature.baselineSharpness * 0.60)),
                                ],
                                relativeTime: 0,
                                duration: 60
                            )
                        ], parameters: [])
                    let player = try engine.makeAdvancedPlayer(with: pattern)
                    try player.start(atTime: CHHapticTimeImmediate)
                    bedPlayer = player
                } catch {}
            }

            let interval = signature.baselineTickIntervalMs / 1000.0
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + interval, repeating: interval)
            timer.setEventHandler { [weak self] in
                self?.tactileTick()
            }
            timer.resume()
            tickTimer = timer
        }

        public func updateTactileReading(dotCount: Int) {
            currentDotCount = max(0, min(dotCount, 6))
            // Every drag update should be felt; add a short boost window.
            movementBoostTicksRemaining = 3
        }

        public func stopTactileReading() {
            tickTimer?.cancel()
            tickTimer = nil

            #if canImport(UIKit)
                impactGenerator = nil
            #endif

            do { try bedPlayer?.stop(atTime: CHHapticTimeImmediate) } catch {}
            bedPlayer = nil
            currentDotCount = 0
            movementBoostTicksRemaining = 0
        }

        private func tactileTick() {
            let dc = currentDotCount
            let signature = currentSignature
            let elapsed = ProcessInfo.processInfo.systemUptime - readingStartUptime
            let frame = signature.baselineFrame(tickIndex: tickIndex, elapsed: elapsed)

            // Blend signature baseline with dot density
            let baselineTickIntensity = signature.baselineIntensity * frame.tickIntensityScale
            let dotTickIntensity = Double(TactileDensity.tickIntensity(dotCount: dc))
            let blendedTickIntensity = clamped(
                (baselineTickIntensity * 0.45) + (dotTickIntensity * 0.55))

            let baselineBedIntensity = signature.baselineIntensity * frame.bedIntensityScale
            let dotBedIntensity = Double(TactileDensity.bedIntensity(dotCount: dc))
            let blendedBedIntensity = clamped(
                (baselineBedIntensity * 0.40) + (dotBedIntensity * 0.60))

            let baselineSharpness = signature.baselineSharpness * frame.sharpnessScale
            let dotSharpness = Double(TactileDensity.bedSharpness(dotCount: dc))
            let blendedSharpness = clamped((baselineSharpness * 0.45) + (dotSharpness * 0.55))
            let movementBoost = movementBoostTicksRemaining > 0 ? 1.30 : 1.0
            let boostedTickIntensity = clamped(blendedTickIntensity * movementBoost)
            let boostedBedIntensity = clamped(blendedBedIntensity * movementBoost)

            #if canImport(UIKit)
                if frame.tickIsActive {
                    MainActor.assumeIsolated {
                        impactGenerator?.impactOccurred(intensity: CGFloat(boostedTickIntensity))
                        impactGenerator?.prepare()
                    }
                }
            #endif

            if let bedPlayer {
                try? bedPlayer.sendParameters(
                    [
                        CHHapticDynamicParameter(
                            parameterID: .hapticIntensityControl,
                            value: Float(boostedBedIntensity),
                            relativeTime: 0),
                        CHHapticDynamicParameter(
                            parameterID: .hapticSharpnessControl,
                            value: Float(blendedSharpness),
                            relativeTime: 0),
                    ], atTime: CHHapticTimeImmediate)
            }

            if movementBoostTicksRemaining > 0 {
                movementBoostTicksRemaining -= 1
            }
            tickIndex += 1
        }

        private func clamped(_ value: Double) -> Double {
            min(max(value, 0.0), 1.0)
        }

        // MARK: - Pattern mapping

        static func pattern(for event: HapticEvent) -> CHHapticPattern {
            let events: [CHHapticEvent]
            switch event {
            case .categorySwitch:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                        ], relativeTime: 0)
                ]

            case .sendSuccess:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                        ], relativeTime: 0),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                        ], relativeTime: 0.1),
                ]

            case .sendFailure:
                events = [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                        ], relativeTime: 0, duration: 0.3)
                ]

            case .endOfCategory:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                        ], relativeTime: 0),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                        ], relativeTime: 0.15),
                ]

            case .urgentQueuedAlert:
                events = [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                        ], relativeTime: 0, duration: 0.5)
                ]

            case .enterFullMode:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                        ], relativeTime: 0)
                ]

            case .focusChanged:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                        ], relativeTime: 0)
                ]

            case .preview:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                        ], relativeTime: 0)
                ]

            case .activate:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                        ], relativeTime: 0),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                        ], relativeTime: 0.08),
                ]

            case .urgentTriplePulse:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                        ], relativeTime: 0),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                        ], relativeTime: 0.1),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                        ], relativeTime: 0.2),
                ]

            case .freezeConfirm:
                events = [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                        ], relativeTime: 0),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                        ], relativeTime: 0.15),
                ]
            }

            return try! CHHapticPattern(events: events, parameters: [])
        }
    }
#endif
