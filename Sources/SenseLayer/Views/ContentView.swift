import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var state: AppState

    public init() {}

    public var body: some View {
        BrailleAccessOverlayView()
            .onAppear {
                if !state.isActive {
                    state.enterMode()
                }
            }
    }
}
