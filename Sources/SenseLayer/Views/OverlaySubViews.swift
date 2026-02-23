import SwiftUI

struct AppLauncherView: View {
    private let apps = ["Messages", "Mail", "Safari", "Maps", "Calendar", "Notes", "Clock", "Calculator"]
    var body: some View { overlayList(title: "Launch App", items: apps) }
}

struct ChooserView: View {
    private let items = ["Option A", "Option B", "Option C", "Option D"]
    var body: some View { overlayList(title: "Choose Item", items: items) }
}

struct BrailleNotesView: View {
    @State private var noteText = "Sample braille note content."

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                glassHeader("Braille Notes")
                BrailleTextDotsView(String(noteText.prefix(30)), dotSize: 4, cellSpacing: 5)
                    .padding(.horizontal)
                TextEditor(text: $noteText)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .font(.body.monospaced())
                    .padding()
                    .glassEffect(.clear, in: .rect(cornerRadius: 14))
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.top)
        }
        .preferredColorScheme(.dark)
    }
}

struct BRFFilesView: View {
    private let files = ["document.brf", "notes_2026.brf", "homework.brf", "recipe.brf", "letter.brf"]
    var body: some View { overlayList(title: "BRF Files", items: files) }
}

struct LiveCaptionsView: View {
    @State private var captionText = "Live captions will appear here as speech is detected..."

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                glassHeader("Live Captions")
                BrailleTextDotsView(String(captionText.prefix(24)), dotSize: 5, cellSpacing: 6)
                    .padding(.horizontal)
                Text(captionText)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
                HStack(spacing: 10) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text("Listening...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 40)
            }
            .padding(.top)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Shared

@MainActor
private func overlayList(title: String, items: [String]) -> some View {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 0) {
            glassHeader(title)
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 4) {
                            BrailleTextDotsView(item, dotSize: 3, cellSpacing: 4)
                            Text(item)
                                .font(.body)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(.clear, in: .rect(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    .preferredColorScheme(.dark)
}

@MainActor
private func glassHeader(_ title: String) -> some View {
    VStack(spacing: 6) {
        BrailleTextDotsView(title, dotSize: 3, cellSpacing: 5)
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
}
