import SwiftUI
import SenseLayer

@main
struct SenseLayerApp: App {
    @StateObject private var state: AppState = {
        let repo = InMemoryMessageRepository(seed: 42, count: 15)
        #if canImport(CoreHaptics)
        let haptics = CoreHapticService()
        #else
        let haptics = NoOpHapticService()
        #endif
        return AppState(
            repo: repo,
            drafts: DraftStore(),
            sender: MockSendService(mode: .success),
            scheduler: SystemScheduler(),
            haptics: haptics
        )
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
    }
}
