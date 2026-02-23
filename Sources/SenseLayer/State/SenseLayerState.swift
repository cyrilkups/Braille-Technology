import Combine
import Foundation

public enum ReadingMode: Equatable {
    case summary
    case full
}

public enum SendResult: Equatable {
    case sent
    case failed
}

public enum InputMode: Equatable {
    case sequential
    case fullScreenChorded
}

/// Phases of the fraud alert demo scenario overlay.
public enum FraudAlertPhase: Equatable {
    case alert
    case frozen
    case calling
}

/// Menu items in the Braille Access overlay panel.
public enum OverlayMenuItem: String, CaseIterable, Equatable {
    case launchApp = "Launch App"
    case chooseItem = "Choose Item"
    case brailleNotes = "Braille Notes"
    case brfFiles = "BRF Files"
    case previewStrip = "Preview Strip"
    case liveCaptions = "Live Captions"
    case close = "Close"
}

/// Which sub-view is currently presented from the overlay.
public enum OverlayDestination: Equatable {
    case appLauncher
    case chooser
    case brailleNotes
    case brfFiles
    case liveCaptions
}

/// Inactivity auto-exit timeout in seconds.
let senseLayerInactivityTimeout: TimeInterval = 60

/// Core state machine for SenseLayer. Generic over `Haptics` so tests can
/// inject `SpyHapticService` and inspect played events.
public final class SenseLayerState<Haptics: HapticService>: ObservableObject {

    // MARK: - Dependencies

    private var repo: any MessageRepository
    private var drafts: DraftStore
    public var sender: any SendService
    private var scheduler: any Scheduler
    public var haptics: Haptics

    // MARK: - Loaded data

    private var allMessages: [Message] = []
    private var inactivityToken: (any Cancellable)?
    public private(set) var urgentQueue: [Message] = []

    // MARK: - Published state

    @Published public var isActive: Bool = false
    @Published public var currentMode: SenseMode = .home
    @Published public var activeCategoryIndex: Int = 0
    @Published public var activeMessageIndex: Int = 0
    @Published public var readingMode: ReadingMode = .summary
    @Published public var isComposing: Bool = false
    @Published public var currentDraft: String = ""
    @Published public var lastSendResult: SendResult? = nil
    @Published public var overlayFocusIndex: Int = 0
    @Published public var overlayDestination: OverlayDestination? = nil
    @Published public var previewStripText: String = "hello world braille access"
    @Published public private(set) var demoScenario: DemoScenario? = nil
    @Published public private(set) var isUrgentOnlyEnabled: Bool = false
    @Published public var judgeMode: Bool = true
    @Published public var composeDotMask: Int = 0
    @Published public var fraudAlertPhase: FraudAlertPhase? = nil
    @Published public var inputMode: InputMode = .sequential

    // MARK: - Computed

    public var overlayMenuItems: [OverlayMenuItem] { OverlayMenuItem.allCases }

    public var categories: [MessageCategory] { [.urgent, .personal, .work, .other] }

    public var messagesInActiveCategory: [Message] {
        let cat = categories[activeCategoryIndex]
        return allMessages.filter { $0.category == cat }
    }

    public var currentMessage: Message? {
        let msgs = messagesInActiveCategory
        guard activeMessageIndex < msgs.count else { return nil }
        return msgs[activeMessageIndex]
    }

    public func countByCategory(_ category: MessageCategory) -> Int {
        allMessages.filter { $0.category == category }.count
    }

    /// The message being actively viewed or composed to.
    /// In read mode, uses the ReadContext message; otherwise falls back to category-based currentMessage.
    public var activeMessage: Message? {
        if case .read(let ctx) = currentMode {
            return ctx.message
        }
        return currentMessage
    }

    public var topMessage: Message? {
        // First, try urgent queue
        if let first = urgentQueue.first { return first }
        // Otherwise, return first message overall
        return allMessages.first
    }

    public var topUrgentMessage: Message? {
        if let queued = urgentQueue.first { return queued }
        return allMessages.first(where: { $0.category == .urgent })
    }

    public var homeTopMessage: Message? {
        isUrgentOnlyEnabled ? topUrgentMessage : topMessage
    }

    public var allApps: [String] {
        ["Messages", "Mail", "Slack", "Teams", "Notes", "Phone"]
    }

    public var conversations: [Message] {
        // Return all messages grouped by sender
        var seen = Set<String>()
        return allMessages.filter { msg in
            guard !seen.contains(msg.senderName) else { return false }
            seen.insert(msg.senderName)
            return true
        }
    }

    public func messageFrom(senderName: String) -> Message? {
        allMessages.first(where: { $0.senderName == senderName })
    }

    /// Opens a conversation from the navigate list.
    /// Bank Alert routes into the simple fraud response scenario.
    public func openConversation(senderName: String, appID: String) {
        guard let message = messageFrom(senderName: senderName) else { return }

        if shouldTriggerFraudScenario(for: message) {
            enterHomeMode()
            enterFraudAlert()
            return
        }

        enterReadMode(ReadContext(message: message, appName: appID))
    }

    // MARK: - Init

    public init(
        repo: any MessageRepository,
        drafts: DraftStore = DraftStore(),
        sender: any SendService = MockSendService(mode: .success),
        scheduler: any Scheduler = SystemScheduler(),
        haptics: Haptics
    ) {
        self.repo = repo
        self.drafts = drafts
        self.sender = sender
        self.scheduler = scheduler
        self.haptics = haptics
    }

    // MARK: - Mode

    public func enterMode() {
        if let scenario = demoScenario {
            allMessages = scenario.messages
            activeCategoryIndex = categoryIndex(for: scenario.focusCategory)
        } else {
            allMessages = repo.loadMessages()
            activeCategoryIndex = 0
        }
        isUrgentOnlyEnabled = false
        isActive = true
        currentMode = .home
        activeMessageIndex = 0
        readingMode = .summary
        isComposing = false
        currentDraft = ""
        if demoScenario == .bankFraud {
            fraudAlertPhase = .alert
            haptics.play(.urgentTriplePulse)
        } else {
            fraudAlertPhase = nil
        }
        resetInactivityTimer()
    }

    public func selectDemoScenario(_ scenario: DemoScenario) {
        demoScenario = scenario
        allMessages = scenario.messages
        activeCategoryIndex = categoryIndex(for: scenario.focusCategory)
        activeMessageIndex = 0
        readingMode = .summary
        isComposing = false
        currentDraft = ""
        urgentQueue.removeAll()
        if isActive {
            currentMode = .home
            overlayDestination = nil
            overlayFocusIndex = 0
            resetInactivityTimer()
            haptics.play(.categorySwitch)
        }
    }

    public func clearDemoScenario() {
        demoScenario = nil
    }

    public func exitMode() {
        inactivityToken?.cancel()
        inactivityToken = nil
        saveDraftIfComposing()
        drainUrgentQueue()
        isActive = false
        currentMode = .home
        isUrgentOnlyEnabled = false
        isComposing = false
    }

    public func registerInteraction() {
        guard isActive else { return }
        resetInactivityTimer()
    }

    // MARK: - Category navigation

    public func nextCategory() {
        guard isActive, activeCategoryIndex < categories.count - 1 else { return }
        saveDraftIfComposing()
        activeCategoryIndex += 1
        activeMessageIndex = 0
        readingMode = .summary
        isComposing = false
        currentDraft = ""
        haptics.play(.categorySwitch)
    }

    public func prevCategory() {
        guard isActive, activeCategoryIndex > 0 else { return }
        saveDraftIfComposing()
        activeCategoryIndex -= 1
        activeMessageIndex = 0
        readingMode = .summary
        isComposing = false
        currentDraft = ""
        haptics.play(.categorySwitch)
    }

    // MARK: - Message navigation

    public func nextMessage() {
        guard isActive else { return }
        let msgs = messagesInActiveCategory
        guard !msgs.isEmpty else { return }
        if activeMessageIndex >= msgs.count - 1 {
            haptics.play(.endOfCategory)
            return
        }
        saveDraftIfComposing()
        activeMessageIndex += 1
        readingMode = .summary
        isComposing = false
        currentDraft = ""
    }

    // MARK: - Reading mode

    public func enterFullMode() {
        guard isActive, currentMessage != nil else { return }
        readingMode = .full
        haptics.play(.enterFullMode)
    }

    public func exitFullMode() {
        readingMode = .summary
    }

    // MARK: - Reply

    public func startReply() {
        guard isActive, let msg = activeMessage else { return }
        isComposing = true
        composeDotMask = 0
        currentDraft = drafts.loadDraft(conversationKey: msg.senderName) ?? ""
    }

    public func appendCharacter(_ char: Character) {
        guard isComposing else { return }
        currentDraft.append(char)
    }

    public func deleteLastChar() {
        guard isComposing, !currentDraft.isEmpty else { return }
        currentDraft.removeLast()
    }

    public func toggleDot(_ dotIndex: Int) {
        guard isComposing, (0..<6).contains(dotIndex) else { return }
        composeDotMask ^= (1 << dotIndex)
        haptics.play(.focusChanged)
    }

    public func commitBrailleChar() {
        guard isComposing else { return }
        let mask = composeDotMask
        composeDotMask = 0
        guard mask > 0 else { return }
        if let char = BrailleMapping.map(mask) {
            currentDraft.append(char)
        }
        haptics.play(.preview)
    }

    public func commitSpace() {
        guard isComposing else { return }
        currentDraft.append(" ")
        composeDotMask = 0
        haptics.play(.preview)
    }

    // MARK: - Chord input

    public func toggleInputMode() {
        inputMode = inputMode == .sequential ? .fullScreenChorded : .sequential
        haptics.play(.enterFullMode)
    }

    public func commitChordChar(dotMask: Int) {
        guard isComposing else { return }
        guard dotMask > 0 else { return }
        if let char = BrailleMapping.map(dotMask) {
            currentDraft.append(char)
            haptics.play(.preview)
        }
    }

    // MARK: - Send

    @MainActor
    public func sendDraft() async {
        guard isComposing, let msg = activeMessage else { return }
        let svc = sender
        let key = msg.senderName
        let text = currentDraft
        do {
            try await svc.send(conversationKey: key, text: text)
            currentDraft = ""
            composeDotMask = 0
            drafts.clearDraft(conversationKey: msg.senderName)
            isComposing = false
            lastSendResult = .sent
            haptics.play(.sendSuccess)
        } catch {
            lastSendResult = .failed
            haptics.play(.sendFailure)
        }
    }

    // MARK: - Incoming messages

    public func receiveNewMessage(_ message: Message) {
        guard isActive else { return }
        allMessages.append(message)
        if message.category == .urgent {
            urgentQueue.append(message)
        }
    }

    public func exitCategoryToDashboard() {
        guard isActive else { return }
        saveDraftIfComposing()
        drainUrgentQueue()
        activeCategoryIndex = 0
        activeMessageIndex = 0
        readingMode = .summary
        isComposing = false
        currentDraft = ""
    }

    // MARK: - Overlay navigation

    public func overlayFocusNext() {
        let count = overlayMenuItems.count
        overlayFocusIndex = (overlayFocusIndex + 1) % count
        haptics.play(.categorySwitch)
    }

    public func overlayFocusPrev() {
        let count = overlayMenuItems.count
        overlayFocusIndex = (overlayFocusIndex - 1 + count) % count
        haptics.play(.categorySwitch)
    }

    public func overlaySelect() {
        let item = overlayMenuItems[overlayFocusIndex]
        switch item {
        case .launchApp:
            enterNavigateMode(.apps)
        case .chooseItem: overlayDestination = .chooser
        case .brailleNotes: overlayDestination = .brailleNotes
        case .brfFiles: overlayDestination = .brfFiles
        case .liveCaptions: overlayDestination = .liveCaptions
        case .previewStrip: break
        case .close: exitMode()
        }
    }

    public func overlayDismissDestination() {
        overlayDestination = nil
    }

    public func takeMeBack() {
        guard isActive else { return }
        switch currentMode {
        case .home:
            exitMode()
        case .navigate:
            enterHomeMode()
        case .read(let context):
            if isComposing {
                saveDraftIfComposing()
                isComposing = false
                composeDotMask = 0
            } else if let appName = context.appName {
                enterNavigateMode(.conversations(appID: appName))
            } else {
                enterHomeMode()
            }
        }
    }

    public func toggleJudgeMode() {
        judgeMode.toggle()
    }

    public func toggleUrgentOnly() {
        guard isActive else { return }
        isUrgentOnlyEnabled.toggle()
        activeMessageIndex = 0
        readingMode = .summary
        isComposing = false
        currentDraft = ""
        haptics.play(.sendSuccess)
    }

    // MARK: - Fraud alert demo

    /// Enter the fraud alert demo from home screen.
    public func enterFraudAlert() {
        guard isActive, currentMode == .home else { return }
        fraudAlertPhase = .alert
        haptics.play(.urgentTriplePulse)
    }

    /// Freeze the card — transition to confirmation state.
    public func fraudFreezeCard() {
        guard fraudAlertPhase == .alert else { return }
        fraudAlertPhase = .frozen
        haptics.play(.freezeConfirm)
    }

    /// Simulate calling the bank.
    public func fraudCallBank() {
        guard fraudAlertPhase == .alert else { return }
        fraudAlertPhase = .calling
        haptics.play(.activate)
    }

    /// Dismiss the fraud alert and return to normal home.
    public func fraudDismiss() {
        fraudAlertPhase = nil
        haptics.play(.categorySwitch)
    }

    // MARK: - Mode transitions

    public func enterHomeMode() {
        currentMode = .home
        activeCategoryIndex = 0
        activeMessageIndex = 0
        readingMode = .summary
        isComposing = false
        currentDraft = ""
        composeDotMask = 0
        overlayFocusIndex = 0
        haptics.play(.categorySwitch)
    }

    public func enterNavigateMode(_ context: NavigateContext) {
        currentMode = .navigate(context: context)
        activeCategoryIndex = 0
        activeMessageIndex = 0
        readingMode = .summary
        isComposing = false
        currentDraft = ""
        haptics.play(.categorySwitch)
    }

    public func enterReadMode(_ context: ReadContext) {
        currentMode = .read(context: context)
        readingMode = .summary
        isComposing = false
        currentDraft = ""
        haptics.play(.categorySwitch)
    }

    // MARK: - Two-layer tactile reading session

    public func beginTactileReading() {
        let signature: HapticSignature
        switch currentMode {
        case .read(let context):
            signature = context.hapticSignature
        case .home:
            signature = isUrgentOnlyEnabled ? .urgent : .neutral
        case .navigate:
            signature = .neutral
        }
        haptics.startTactileReading(signature: signature)
    }

    /// Store the dot count for the cell under the finger.
    /// The timer inside the haptic engine drives the actual tick cadence.
    public func updateTactileReading(dotCount: Int) {
        haptics.updateTactileReading(dotCount: dotCount)
    }

    public func stopTactileReading() {
        haptics.stopTactileReading()
    }

    // MARK: - Internal

    private func saveDraftIfComposing() {
        if isComposing, let msg = activeMessage {
            drafts.saveDraft(conversationKey: msg.senderName, text: currentDraft)
        }
    }

    private func drainUrgentQueue() {
        if !urgentQueue.isEmpty {
            haptics.play(.urgentQueuedAlert)
            urgentQueue.removeAll()
        }
    }

    private func categoryIndex(for category: MessageCategory) -> Int {
        categories.firstIndex(of: category) ?? 0
    }

    private func shouldTriggerFraudScenario(for message: Message) -> Bool {
        message.senderName.compare("Bank Alert", options: .caseInsensitive) == .orderedSame
    }

    private func resetInactivityTimer() {
        inactivityToken?.cancel()
        inactivityToken = scheduler.schedule(after: senseLayerInactivityTimeout) { [weak self] in
            guard let self, self.isActive else { return }
            self.exitMode()
        }
    }
}
