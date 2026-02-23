import Foundation

#if canImport(CoreHaptics)
/// On devices with CoreHaptics (all iOS), use the real haptic engine.
/// Falls back gracefully when hardware doesn't support haptics (e.g. Simulator).
public typealias AppState = SenseLayerState<CoreHapticService>
#else
public typealias AppState = SenseLayerState<NoOpHapticService>
#endif
