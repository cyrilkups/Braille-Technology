import Foundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Triple-Finger Double-Tap Detector

#if canImport(UIKit)
    class TripleFingerGestureRecognizer: UIGestureRecognizer {
        var tapCount: Int = 0
        var activeTouchCount: Int = 0
        var onTripleFingerDoubleTap: (() -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            activeTouchCount += touches.count

            if activeTouchCount >= 3 {
                tapCount += 1
                if tapCount == 2 {
                    onTripleFingerDoubleTap?()
                    tapCount = 0
                    activeTouchCount = 0
                }
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            activeTouchCount = max(0, activeTouchCount - touches.count)

            if activeTouchCount == 0 {
                // Reset tap count when all touches are released
                if tapCount < 2 {
                    tapCount = 0
                }
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            activeTouchCount = max(0, activeTouchCount - touches.count)
            if activeTouchCount == 0 {
                tapCount = 0
            }
        }
    }

    struct TripleFingerGestureRepresentable: UIViewRepresentable {
        var onTripleFingerDoubleTap: () -> Void

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            let gesture = TripleFingerGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTripleFingerDoubleTap))
            gesture.onTripleFingerDoubleTap = onTripleFingerDoubleTap
            view.addGestureRecognizer(gesture)
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        class Coordinator: NSObject {
            @objc func handleTripleFingerDoubleTap() {}
        }
    }
#endif

/// Captures frame information for a tactile row, including the braille content width
/// so haptics only fire when the finger is over actual braille dots.
struct RowFrameInfo: Hashable {
    let id: String
    let text: String
    let frame: CGRect
    let brailleWidth: CGFloat

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RowFrameInfo, rhs: RowFrameInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// PreferenceKey for collecting row frames from all draggable rows.
struct RowFramePreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [RowFrameInfo] = []
    static func reduce(value: inout [RowFrameInfo], nextValue: () -> [RowFrameInfo]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Main View

/// Deafblind-first Braille Access overlay.
/// Interaction: vertical swipe changes focus, single tap previews, double tap activates.
/// Horizontal drag across braille dots triggers continuous tactile reading.
public struct BrailleAccessOverlayView: View {
    @EnvironmentObject var state: AppState

    @State private var rowFrames: [RowFrameInfo] = []
    @State private var focusedRowIndex: Int = 0
    @State private var singleTapWorkItem: DispatchWorkItem?

    @State private var lastTactileRowId: String? = nil
    @State private var lastTactileWordIndex: Int? = nil
    @State private var lastTactileCellIndex: Int? = nil
    @State private var isTactileReading = false
    @State private var isReadingFullMessage = false

    #if canImport(UIKit)
        @StateObject private var tactileEngine = TactileEngine()
    #endif

    private var sortedRows: [RowFrameInfo] {
        rowFrames.sorted { $0.frame.minY < $1.frame.minY }
    }

    private func isFocused(rowId: String) -> Bool {
        let rows = sortedRows
        guard focusedRowIndex >= 0, focusedRowIndex < rows.count else { return false }
        return rows[focusedRowIndex].id == rowId
    }

    /// Computes the rendered pixel width of a BrailleDotsView for the given parameters.
    /// BrailleDotsView uses default dotSpacing = 3 when not explicitly provided.
    private func brailleContentWidth(charCount: Int, dotSize: CGFloat, cellSpacing: CGFloat)
        -> CGFloat
    {
        let n = CGFloat(charCount)
        guard n > 0 else { return 0 }
        let cellWidth = 2 * dotSize + 3
        return n * cellWidth + max(n - 1, 0) * cellSpacing
    }

    /// Caps tactile braille width so interaction bounds never exceed the rendered row width.
    private func cappedBrailleWidth(_ contentWidth: CGFloat, rowWidth: CGFloat) -> CGFloat {
        min(contentWidth, max(rowWidth, 0))
    }

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Full-screen chord input (no overlay panel)
            if state.isComposing && state.inputMode == .fullScreenChorded {
                BrailleChordInputView()
            } else {
                // Regular overlay panel
                GlassEffectContainer {
                    VStack(spacing: 0) {
                        panelHeader
                        Divider().background(Color.white.opacity(0.15))
                        ScrollViewReader { proxy in
                            ScrollView {
                                modeContentView
                            }
                            .onChange(of: focusedRowIndex) { _, newIndex in
                                let rows = sortedRows
                                if newIndex >= 0, newIndex < rows.count {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(rows[newIndex].id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 40)
                }
                .contentShape(Rectangle())
                .coordinateSpace(name: "brailleArea")
                .simultaneousGesture(globalTactileDragGesture)
            }
        }
        // Global fallback taps (for empty-space taps that miss any row)
        .onTapGesture(count: 2) {
            singleTapWorkItem?.cancel()
            singleTapWorkItem = nil
            activateFocusedRow()
        }
        .onTapGesture(count: 1) {
            state.registerInteraction()
            singleTapWorkItem?.cancel()
            let item = DispatchWorkItem { previewFocusedRow() }
            singleTapWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }
        .onPreferenceChange(RowFramePreferenceKey.self) { frames in
            rowFrames = frames
            let count = frames.count
            if count > 0 && focusedRowIndex >= count {
                focusedRowIndex = count - 1
            }
        }
        .onChange(of: state.currentMode) { _, _ in
            focusedRowIndex = 0
        }
        .onChange(of: state.isComposing) { _, _ in
            focusedRowIndex = 0
        }
        .sheet(item: $state.overlayDestination) { dest in
            destinationView(for: dest)
                .environmentObject(state)
        }
        .preferredColorScheme(.dark)
        #if canImport(UIKit)
            .overlay(
                TripleFingerGestureRepresentable {
                    if state.isComposing {
                        state.toggleInputMode()
                    }
                }
                .frame(width: 0, height: 0)
            )
        #endif
    }

    // MARK: - Tap handling

    private func previewFocusedRow() {
        state.haptics.play(.preview)
    }

    private func activateFocusedRow() {
        state.registerInteraction()
        let rows = sortedRows
        guard focusedRowIndex >= 0, focusedRowIndex < rows.count else { return }
        state.haptics.play(.activate)
        activateRow(id: rows[focusedRowIndex].id)
    }

    /// Single-tap handler for a specific row: moves focus to it and previews.
    private func handleRowSingleTap(id: String) {
        state.registerInteraction()
        singleTapWorkItem?.cancel()
        singleTapWorkItem = nil
        if let idx = sortedRows.firstIndex(where: { $0.id == id }) {
            focusedRowIndex = idx
        }
        let item = DispatchWorkItem { [state] in
            state.haptics.play(.preview)
        }
        singleTapWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    /// Double-tap handler for a specific row: activates it directly.
    private func handleRowDoubleTap(id: String) {
        singleTapWorkItem?.cancel()
        singleTapWorkItem = nil
        state.registerInteraction()
        if let idx = sortedRows.firstIndex(where: { $0.id == id }) {
            focusedRowIndex = idx
        }
        state.haptics.play(.activate)
        // Ensure activation happens on main thread and immediately
        DispatchQueue.main.async { [id, self] in
            self.activateRow(id: id)
        }
    }

    private func activateRow(id: String) {
        switch state.currentMode {
        case .home:
            if state.fraudAlertPhase != nil {
                handleFraudAction(id)
            } else {
                switch id {
                case "action_messages":
                    state.enterNavigateMode(.conversations(appID: "Messages"))
                case "action_notifications":
                    state.haptics.play(.enterFullMode)
                case "action_close":
                    state.exitMode()
                default: break
                }
            }

        case .navigate(let context):
            if id == "nav_back" {
                state.takeMeBack()
            } else if id.hasPrefix("nav_") {
                let items = navigationItems(for: context)
                if let idxStr = id.split(separator: "_").last,
                    let idx = Int(idxStr), idx < items.count
                {
                    handleNavigationSelect(items[idx], context: context)
                }
            }

        case .read:
            if state.isComposing {
                handleComposeAction(id)
            } else {
                handleReadAction(id)
            }
        }
    }

    private func handleReadAction(_ id: String) {
        guard case .read(let ctx) = state.currentMode else { return }
        switch id {
        case "read_full":
            if !isReadingFullMessage {
                isReadingFullMessage = true
                state.beginTactileReading()
                state.haptics.play(.enterFullMode)
                startFullMessageStreaming(ctx)
            } else {
                isReadingFullMessage = false
                state.stopTactileReading()
            }
        case "read_reply":
            state.startReply()
        case "read_next":
            state.nextMessage()
        case "read_back":
            state.takeMeBack()
        default: break
        }
    }

    private func handleComposeAction(_ id: String) {
        switch id {
        case "compose_commit":
            state.commitBrailleChar()
        case "compose_space":
            state.commitSpace()
        case "compose_delete":
            state.deleteLastChar()
        case "compose_send":
            Task { @MainActor in
                await state.sendDraft()
            }
        case "compose_back":
            state.takeMeBack()
        default: break
        }
    }

    private func handleFraudAction(_ id: String) {
        switch id {
        case "fraud_freeze":
            state.fraudFreezeCard()
        case "fraud_call":
            state.fraudCallBank()
        case "fraud_ignore":
            state.fraudDismiss()
        case "fraud_close":
            state.fraudDismiss()
        default: break
        }
    }

    // MARK: - Mode-based content

    @ViewBuilder
    private var modeContentView: some View {
        switch state.currentMode {
        case .home:
            homeOverlayContent
        case .navigate(let context):
            navigateContent(context)
        case .read(context: let readCtx):
            if state.isComposing {
                composeContent(readCtx)
            } else {
                readContent(readCtx)
            }
        }
    }

    // MARK: - Dynamic header

    private var headerTitle: String {
        if state.isComposing {
            if case .read(let ctx) = state.currentMode {
                return "reply to \(ctx.message.senderName.lowercased())"
            }
            return "composing"
        }
        if case .home = state.currentMode, let phase = state.fraudAlertPhase {
            switch phase {
            case .alert: return "fraud alert"
            case .frozen: return "card frozen"
            case .calling: return "calling bank"
            }
        }
        switch state.currentMode {
        case .home:
            return "braille access"
        case .navigate(let ctx):
            return navigationTitle(for: ctx).lowercased()
        case .read(let ctx):
            return ctx.message.senderName.lowercased()
        }
    }

    private var panelHeader: some View {
        let title = headerTitle
        let ds = BrailleStyle.large.dotSize
        let cs = BrailleStyle.large.cellSpacing
        let bw = brailleContentWidth(charCount: title.count, dotSize: ds, cellSpacing: cs)

        return GeometryReader { geo in
            VStack(spacing: 8) {
                BrailleTextDotsView(title, dotSize: ds, cellSpacing: cs)
                    .clipped()
                    .padding(.top, 16)
                if state.judgeMode {
                    Text(title.capitalized)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
            .glassEffect(
                isFocused(rowId: "header") ? .regular : .clear, in: .rect(cornerRadius: 12)
            )
            .contentShape(Rectangle())
            .preference(
                key: RowFramePreferenceKey.self,
                value: [
                    RowFrameInfo(
                        id: "header",
                        text: title,
                        frame: geo.frame(in: .named("brailleArea")),
                        brailleWidth: cappedBrailleWidth(bw, rowWidth: geo.size.width))
                ])
        }
        .frame(height: 72)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { handleRowDoubleTap(id: "header") }
        .onTapGesture(count: 1) { handleRowSingleTap(id: "header") }
    }

    // MARK: - Home mode content

    @ViewBuilder
    private var homeOverlayContent: some View {
        if let phase = state.fraudAlertPhase {
            fraudAlertContent(phase)
        } else {
            VStack(spacing: 4) {
                overlayRow("Messages", id: "action_messages")
                overlayRow("Notifications", id: "action_notifications")
                overlayRow("Close", id: "action_close")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
    }

    private func fraudAlertContent(_ phase: FraudAlertPhase) -> some View {
        VStack(spacing: 4) {
            switch phase {
            case .alert:
                fraudUrgentRow(
                    "Fraud Alert", subtitle: "Card activity detected", id: "fraud_header")
                overlayRow("Freeze Card", id: "fraud_freeze")
                overlayRow("Call Bank", id: "fraud_call")
                overlayRow("Ignore", id: "fraud_ignore")
            case .frozen:
                fraudConfirmRow(
                    "Card Frozen", subtitle: "Your card has been secured", id: "fraud_done")
                overlayRow("Close", id: "fraud_close")
            case .calling:
                fraudConfirmRow("Calling Bank", subtitle: "Please hold", id: "fraud_calling")
                overlayRow("Close", id: "fraud_close")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .padding(.bottom, 12)
    }

    /// Urgent-styled row with a subtle red tint and larger braille.
    private func fraudUrgentRow(_ title: String, subtitle: String, id: String) -> some View {
        let ds = BrailleStyle.large.dotSize + 2
        let cs = BrailleStyle.large.cellSpacing + 2
        let bw = brailleContentWidth(charCount: title.count, dotSize: ds, cellSpacing: cs)

        return GeometryReader { geo in
            VStack(spacing: 6) {
                BrailleTextDotsView(title, dotSize: ds, cellSpacing: cs)
                    .clipped()
                if state.judgeMode {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.red.opacity(0.12))
            .glassEffect(
                isFocused(rowId: id) ? .regular : .clear,
                in: .rect(cornerRadius: 12)
            )
            .contentShape(Rectangle())
            .preference(
                key: RowFramePreferenceKey.self,
                value: [
                    RowFrameInfo(
                        id: id, text: title,
                        frame: geo.frame(in: .named("brailleArea")),
                        brailleWidth: cappedBrailleWidth(bw, rowWidth: geo.size.width))
                ])
        }
        .frame(height: 84)
        .id(id)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { handleRowDoubleTap(id: id) }
        .onTapGesture(count: 1) { handleRowSingleTap(id: id) }
    }

    /// Confirmation row (green-tinted) for post-action states.
    private func fraudConfirmRow(_ title: String, subtitle: String, id: String) -> some View {
        let bw = brailleContentWidth(
            charCount: title.count,
            dotSize: BrailleStyle.large.dotSize,
            cellSpacing: BrailleStyle.large.cellSpacing)

        return GeometryReader { geo in
            VStack(spacing: 6) {
                BrailleTextDotsView(
                    title,
                    dotSize: BrailleStyle.large.dotSize,
                    cellSpacing: BrailleStyle.large.cellSpacing)
                if state.judgeMode {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green.opacity(0.10))
            .glassEffect(
                isFocused(rowId: id) ? .regular : .clear,
                in: .rect(cornerRadius: 12)
            )
            .contentShape(Rectangle())
            .preference(
                key: RowFramePreferenceKey.self,
                value: [
                    RowFrameInfo(
                        id: id, text: title,
                        frame: geo.frame(in: .named("brailleArea")),
                        brailleWidth: cappedBrailleWidth(bw, rowWidth: geo.size.width))
                ])
        }
        .frame(height: 80)
        .id(id)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { handleRowDoubleTap(id: id) }
        .onTapGesture(count: 1) { handleRowSingleTap(id: id) }
    }

    // MARK: - Navigate mode content

    @ViewBuilder
    private func navigateContent(_ context: NavigateContext) -> some View {
        VStack(spacing: 4) {
            VStack(spacing: 4) {
                ForEach(Array(navigationItems(for: context).enumerated()), id: \.offset) {
                    index, item in
                    overlayRow(item, id: "nav_\(index)")
                }
                overlayRow("Back", id: "nav_back")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Read mode content

    @ViewBuilder
    private func readContent(_ readCtx: ReadContext) -> some View {
        VStack(spacing: 4) {
            messageSummaryRow(readCtx)
            Divider().background(Color.white.opacity(0.15))
            fullMessageRow(readCtx)
            Divider().background(Color.white.opacity(0.15))

            VStack(spacing: 4) {
                overlayRow("Reply", id: "read_reply")
                overlayRow("Next Message", id: "read_next")
                overlayRow("Back", id: "read_back")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 12)
    }

    private func messageSummaryRow(_ readCtx: ReadContext) -> some View {
        let brailleText = String(readCtx.message.body.prefix(30))
        let bw = brailleContentWidth(
            charCount: brailleText.count,
            dotSize: BrailleStyle.large.dotSize,
            cellSpacing: BrailleStyle.large.cellSpacing)

        return GeometryReader { geo in
            VStack(spacing: 6) {
                BrailleTextDotsView(
                    brailleText,
                    dotSize: BrailleStyle.large.dotSize,
                    cellSpacing: BrailleStyle.large.cellSpacing)
                if state.judgeMode {
                    HStack {
                        Text(readCtx.message.senderName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        if readCtx.message.category == .urgent {
                            Text("⚠").font(.caption)
                        }
                    }
                    Text(
                        String(readCtx.message.body.prefix(80))
                            + (readCtx.message.body.count > 80 ? "..." : "")
                    )
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                isFocused(rowId: "read_summary") ? .regular : .clear,
                in: .rect(cornerRadius: 12)
            )
            .contentShape(Rectangle())
            .preference(
                key: RowFramePreferenceKey.self,
                value: [
                    RowFrameInfo(
                        id: "read_summary",
                        text: brailleText,
                        frame: geo.frame(in: .named("brailleArea")),
                        brailleWidth: cappedBrailleWidth(bw, rowWidth: geo.size.width))
                ])
        }
        .frame(height: 76)
        .id("read_summary")
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { handleRowDoubleTap(id: "read_summary") }
        .onTapGesture(count: 1) { handleRowSingleTap(id: "read_summary") }
    }

    private func fullMessageRow(_ readCtx: ReadContext) -> some View {
        let brailleText =
            isReadingFullMessage
            ? String(readCtx.message.body.prefix(40))
            : "full message"
        let bw = brailleContentWidth(
            charCount: brailleText.count,
            dotSize: BrailleStyle.large.dotSize,
            cellSpacing: BrailleStyle.large.cellSpacing)

        return GeometryReader { geo in
            VStack(spacing: 6) {
                BrailleTextDotsView(
                    brailleText,
                    dotSize: BrailleStyle.large.dotSize,
                    cellSpacing: BrailleStyle.large.cellSpacing)
                if state.judgeMode {
                    Text(isReadingFullMessage ? "Reading..." : "Full Message")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isReadingFullMessage ? .cyan : .white.opacity(0.4))
                    if isReadingFullMessage {
                        Text(readCtx.message.body)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                            .lineLimit(3)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                isFocused(rowId: "read_full") || isReadingFullMessage ? .regular : .clear,
                in: .rect(cornerRadius: 12)
            )
            .contentShape(Rectangle())
            .onLongPressGesture(
                minimumDuration: 0.5,
                pressing: { pressing in
                    if pressing {
                        state.registerInteraction()
                        isReadingFullMessage = true
                        state.beginTactileReading()
                        state.haptics.play(.enterFullMode)
                        startFullMessageStreaming(readCtx)
                    } else {
                        isReadingFullMessage = false
                        state.stopTactileReading()
                    }
                },
                perform: {}
            )
            .preference(
                key: RowFramePreferenceKey.self,
                value: [
                    RowFrameInfo(
                        id: "read_full",
                        text: brailleText,
                        frame: geo.frame(in: .named("brailleArea")),
                        brailleWidth: cappedBrailleWidth(bw, rowWidth: geo.size.width))
                ])
        }
        .frame(height: isReadingFullMessage ? 120 : 76)
        .id("read_full")
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { handleRowDoubleTap(id: "read_full") }
        .onTapGesture(count: 1) { handleRowSingleTap(id: "read_full") }
    }

    private func startFullMessageStreaming(_ readCtx: ReadContext) {
        let cells = BrailleCellMapper.cells(for: readCtx.message.body)
        guard !cells.isEmpty else { return }

        #if canImport(UIKit)
            tactileEngine.start()
        #endif

        let cellInterval: TimeInterval = 0.18
        Task { @MainActor in
            var cellIdx = 0
            while isReadingFullMessage, cellIdx < cells.count * 3 {
                let cell = cells[cellIdx % cells.count]
                #if canImport(UIKit)
                    tactileEngine.updateContent(cellIndex: cellIdx, bitmask: cell.bitmask)
                #endif
                state.updateTactileReading(dotCount: cell.raisedCount)
                cellIdx += 1
                try? await Task.sleep(nanoseconds: UInt64(cellInterval * 1_000_000_000))
            }
            if isReadingFullMessage {
                isReadingFullMessage = false
                state.stopTactileReading()
            }
            #if canImport(UIKit)
                tactileEngine.stop()
            #endif
        }
    }

    // MARK: - Compose mode content (braille keyboard + actions)

    @ViewBuilder
    private func composeContent(_ readCtx: ReadContext) -> some View {
        let draftBraille =
            state.currentDraft.isEmpty ? "empty" : String(state.currentDraft.suffix(20))
        let draftBw = brailleContentWidth(
            charCount: draftBraille.count,
            dotSize: BrailleStyle.large.dotSize,
            cellSpacing: BrailleStyle.large.cellSpacing)

        VStack(spacing: 4) {
            GeometryReader { geo in
                VStack(spacing: 6) {
                    BrailleTextDotsView(
                        draftBraille,
                        dotSize: BrailleStyle.large.dotSize,
                        cellSpacing: BrailleStyle.large.cellSpacing)
                    if state.judgeMode {
                        Text(state.currentDraft.isEmpty ? "(empty draft)" : state.currentDraft)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.35))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(
                    isFocused(rowId: "compose_draft") ? .regular : .clear,
                    in: .rect(cornerRadius: 12)
                )
                .contentShape(Rectangle())
                .preference(
                    key: RowFramePreferenceKey.self,
                    value: [
                        RowFrameInfo(
                            id: "compose_draft",
                            text: draftBraille,
                            frame: geo.frame(in: .named("brailleArea")),
                            brailleWidth: cappedBrailleWidth(draftBw, rowWidth: geo.size.width))
                    ])
            }
            .frame(height: 72)
            .id("compose_draft")
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { handleRowDoubleTap(id: "compose_draft") }
            .onTapGesture(count: 1) { handleRowSingleTap(id: "compose_draft") }

            Divider().background(Color.white.opacity(0.15))

            brailleKeyboard
                .padding(.vertical, 8)

            Divider().background(Color.white.opacity(0.15))

            VStack(spacing: 4) {
                composeButton("Commit", id: "compose_commit")
                composeButton("Space", id: "compose_space")
                composeButton("Delete", id: "compose_delete")
                composeButton("Send", id: "compose_send")
                composeButton("Back", id: "compose_back")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 12)
    }

    /// 6-dot braille keyboard in 2x3 grid. Each dot is a large toggleable button.
    private var brailleKeyboard: some View {
        let dotDiameter: CGFloat = 40
        let dotGap: CGFloat = 16
        let activeMask = state.composeDotMask

        return HStack(spacing: dotGap * 2) {
            VStack(spacing: dotGap) {
                dotButton(
                    index: 0, label: "1", active: activeMask & (1 << 0) != 0, size: dotDiameter)
                dotButton(
                    index: 1, label: "2", active: activeMask & (1 << 1) != 0, size: dotDiameter)
                dotButton(
                    index: 2, label: "3", active: activeMask & (1 << 2) != 0, size: dotDiameter)
            }
            VStack(spacing: dotGap) {
                dotButton(
                    index: 3, label: "4", active: activeMask & (1 << 3) != 0, size: dotDiameter)
                dotButton(
                    index: 4, label: "5", active: activeMask & (1 << 4) != 0, size: dotDiameter)
                dotButton(
                    index: 5, label: "6", active: activeMask & (1 << 5) != 0, size: dotDiameter)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func dotButton(index: Int, label: String, active: Bool, size: CGFloat) -> some View {
        Button {
            state.toggleDot(index)
        } label: {
            ZStack {
                Circle()
                    .fill(active ? Color.white : Color.white.opacity(0.15))
                    .frame(width: size, height: size)
                if state.judgeMode {
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(active ? .black : .white.opacity(0.4))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dot \(label)")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    // MARK: - Generic overlay row (with per-row tap gestures)

    private func overlayRow(_ title: String, id: String) -> some View {
        let bw = brailleContentWidth(
            charCount: title.count,
            dotSize: BrailleStyle.large.dotSize,
            cellSpacing: BrailleStyle.large.cellSpacing)

        return GeometryReader { geo in
            VStack(spacing: 6) {
                BrailleTextDotsView(
                    title,
                    dotSize: BrailleStyle.large.dotSize,
                    cellSpacing: BrailleStyle.large.cellSpacing)
                if state.judgeMode {
                    Text(title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassEffect(
                isFocused(rowId: id) ? .regular : .clear,
                in: .rect(cornerRadius: 12)
            )
            .contentShape(Rectangle())
            .accessibilityLabel(title)
            .preference(
                key: RowFramePreferenceKey.self,
                value: [
                    RowFrameInfo(
                        id: id, text: title,
                        frame: geo.frame(in: .named("brailleArea")),
                        brailleWidth: cappedBrailleWidth(bw, rowWidth: geo.size.width))
                ])
        }
        .frame(height: 68)
        .id(id)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { handleRowDoubleTap(id: id) }
        .onTapGesture(count: 1) { handleRowSingleTap(id: id) }
    }

    /// Compose button: activates on single-tap (direct action, not navigation).
    private func composeButton(_ title: String, id: String) -> some View {
        let bw = brailleContentWidth(
            charCount: title.count,
            dotSize: BrailleStyle.large.dotSize,
            cellSpacing: BrailleStyle.large.cellSpacing)

        return GeometryReader { geo in
            VStack(spacing: 6) {
                BrailleTextDotsView(
                    title,
                    dotSize: BrailleStyle.large.dotSize,
                    cellSpacing: BrailleStyle.large.cellSpacing)
                if state.judgeMode {
                    Text(title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassEffect(
                isFocused(rowId: id) ? .regular : .clear,
                in: .rect(cornerRadius: 12)
            )
            .contentShape(Rectangle())
            .accessibilityLabel(title)
            .preference(
                key: RowFramePreferenceKey.self,
                value: [
                    RowFrameInfo(
                        id: id, text: title,
                        frame: geo.frame(in: .named("brailleArea")),
                        brailleWidth: cappedBrailleWidth(bw, rowWidth: geo.size.width))
                ])
        }
        .frame(height: 68)
        .id(id)
        .contentShape(Rectangle())
        // Single-tap to activate (immediate action)
        .onTapGesture {
            state.registerInteraction()
            if let idx = sortedRows.firstIndex(where: { $0.id == id }) {
                focusedRowIndex = idx
            }
            state.haptics.play(.activate)
            handleComposeAction(id)
        }
    }

    // MARK: - Navigation helpers

    private func navigationTitle(for context: NavigateContext) -> String {
        switch context {
        case .apps: return "Apps"
        case .conversations(let appID): return appID
        case .genericList(let title, _): return title
        }
    }

    private func navigationItems(for context: NavigateContext) -> [String] {
        switch context {
        case .apps: return state.allApps
        case .conversations: return state.conversations.map { $0.senderName }
        case .genericList(_, let items): return items
        }
    }

    private func handleNavigationSelect(_ item: String, context: NavigateContext) {
        switch context {
        case .apps:
            state.enterNavigateMode(.conversations(appID: item))
        case .conversations(let appID):
            state.openConversation(senderName: item, appID: appID)
        case .genericList:
            break
        }
    }

    // MARK: - Global tactile drag gesture

    private func cellIndexAtOffset(_ offset: Double, totalCells: Int) -> Int {
        guard totalCells > 0 else { return 0 }
        return min(Int(offset * Double(totalCells)), totalCells - 1)
    }

    private func wordIndex(for charIndex: Int, in text: String) -> Int? {
        guard charIndex >= 0, charIndex < text.count else { return nil }
        let chars = Array(text)
        guard charIndex < chars.count else { return nil }

        var wordIdx = 0
        var i = 0
        while i < charIndex {
            let char = chars[i]
            if char.isWhitespace || char.isPunctuation {
                i += 1
                while i < charIndex && (chars[i].isWhitespace || chars[i].isPunctuation) {
                    i += 1
                }
                if i < charIndex && !(chars[i].isWhitespace || chars[i].isPunctuation) {
                    wordIdx += 1
                }
            } else {
                i += 1
            }
        }
        return wordIdx
    }

    /// Checks if touchX falls within the braille dot area (centered in the row), with tolerance.
    private func isTouchInBrailleArea(touchX: CGFloat, rowFrame: CGRect, brailleWidth: CGFloat)
        -> Bool
    {
        guard brailleWidth > 0 else { return false }
        let tolerance: CGFloat = 20
        let brailleMinX = rowFrame.midX - brailleWidth / 2 - tolerance
        let brailleMaxX = rowFrame.midX + brailleWidth / 2 + tolerance
        return touchX >= brailleMinX && touchX <= brailleMaxX
    }

    private var globalTactileDragGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .named("brailleArea"))
            .onChanged { value in
                state.registerInteraction()

                let touchY = value.location.y
                let touchX = value.location.x

                // Find which row the finger is in (for focus tracking)
                var hitRow: RowFrameInfo? = nil
                for frameInfo in rowFrames {
                    if frameInfo.frame.contains(CGPoint(x: touchX, y: touchY)) {
                        hitRow = frameInfo
                        break
                    }
                }

                if let row = hitRow {
                    // Sync focus to row under finger
                    if lastTactileRowId != row.id {
                        if lastTactileRowId != nil {
                            state.haptics.play(.focusChanged)
                        }
                        lastTactileRowId = row.id
                        lastTactileWordIndex = nil
                        lastTactileCellIndex = nil

                        if let idx = sortedRows.firstIndex(where: { $0.id == row.id }) {
                            focusedRowIndex = idx
                        }
                    }

                    // Only fire tactile haptics when finger is over the braille dot area
                    let onBraille = isTouchInBrailleArea(
                        touchX: touchX,
                        rowFrame: row.frame,
                        brailleWidth: row.brailleWidth)

                    if onBraille {
                        if !isTactileReading {
                            isTactileReading = true
                            state.beginTactileReading()
                        }

                        #if canImport(UIKit)
                            tactileEngine.start()
                        #endif

                        let cells = BrailleCellMapper.cells(for: row.text)
                        guard !cells.isEmpty else { return }

                        let brailleLeft = row.frame.midX - row.brailleWidth / 2
                        let relativeX = touchX - brailleLeft
                        let cellProgress = min(max(relativeX / row.brailleWidth, 0), 1)
                        let cIdx = cellIndexAtOffset(cellProgress, totalCells: cells.count)
                        let cell = cells[cIdx]

                        #if canImport(UIKit)
                            tactileEngine.updateContent(cellIndex: cIdx, bitmask: cell.bitmask)
                        #endif
                        state.updateTactileReading(dotCount: cell.raisedCount)

                        let currentWordIdx = wordIndex(for: cIdx, in: row.text)
                        if let wordIdx = currentWordIdx, lastTactileWordIndex != wordIdx,
                            lastTactileWordIndex != nil
                        {
                            state.haptics.play(.sendSuccess)
                        }
                        lastTactileWordIndex = currentWordIdx

                        if lastTactileCellIndex != cIdx {
                            lastTactileCellIndex = cIdx
                        }
                    } else {
                        #if canImport(UIKit)
                            tactileEngine.start()
                            tactileEngine.enterEmpty()
                        #endif
                        if isTactileReading {
                            isTactileReading = false
                            state.stopTactileReading()
                        }
                    }
                } else {
                    #if canImport(UIKit)
                        tactileEngine.start()
                        tactileEngine.enterEmpty()
                    #endif
                    if isTactileReading {
                        isTactileReading = false
                        state.stopTactileReading()
                    }
                }
            }
            .onEnded { value in
                stopAndResetTactileReading()

                let v = value.translation.height
                let h = value.translation.width
                if abs(v) > abs(h) * 1.5 && abs(v) > 40 {
                    let rows = sortedRows
                    if v > 0 && focusedRowIndex < rows.count - 1 {
                        focusedRowIndex += 1
                        state.haptics.play(.focusChanged)
                    } else if v < 0 && focusedRowIndex > 0 {
                        focusedRowIndex -= 1
                        state.haptics.play(.focusChanged)
                    }
                }
            }
    }

    private func stopAndResetTactileReading() {
        if isTactileReading {
            isTactileReading = false
            state.stopTactileReading()
        }
        #if canImport(UIKit)
            tactileEngine.stop()
        #endif
        lastTactileRowId = nil
        lastTactileWordIndex = nil
        lastTactileCellIndex = nil
    }

    // MARK: - Destination routing

    @ViewBuilder
    private func destinationView(for dest: OverlayDestination) -> some View {
        switch dest {
        case .appLauncher: AppLauncherView()
        case .chooser: ChooserView()
        case .brailleNotes: BrailleNotesView()
        case .brfFiles: BRFFilesView()
        case .liveCaptions: LiveCaptionsView()
        }
    }
}

extension OverlayDestination: Identifiable {
    public var id: String {
        switch self {
        case .appLauncher: "appLauncher"
        case .chooser: "chooser"
        case .brailleNotes: "brailleNotes"
        case .brfFiles: "brfFiles"
        case .liveCaptions: "liveCaptions"
        }
    }
}
