# SenseLayer — Development Guide

Generated: February 22, 2026

This document consolidates technical implementation details, project roadmap, and development tasks.

Table of Contents:
- [Project Overview](#project-overview)
- [Technical Stack](#technical-stack)
- [Architecture](#architecture)
- [Development Phases](#development-phases)
- [Sprint Breakdown](#sprint-breakdown)
- [state Machine](#state-machine)
- [File Structure](#file-structure)
- [Building & Testing](#building--testing)

---

## Project Overview

**SenseLayer** is an AI-powered post-visual operating system that converts structured digital meaning into tactile intelligence. This MVP demonstrates:

- Tactile-first interface design (no screen required)
- Complete messaging workflow through braille interaction
- Deterministic state machine with 310+ unit tests
- Two-way tactile communication (read + compose + send)
- Fraud alert demonstration scenario

**Vision:** A post-visual operating paradigm where meaning is delivered through the body, not pixels through the eyes.

---

## Technical Stack

| Component | Technology |
|---|---|
| Platform | iOS 26+ |
| Language | Swift 6.2 |
| Framework | SwiftUI |
| State Management | Combine (@Published, ObservableObject) |
| Haptics | CoreHaptics with NoOp fallback |
| Testing | XCTest |
| Build | SPM (Swift Package Manager) |

### Design Constraints

- Zero audio reliance — all feedback is haptic
- Visuals are secondary (optional "Judge Mode" for sighted observers)
- urgencyScore always clamped 0…1
- All model types conform to Equatable & Hashable
- Deterministic, testable state transitions

---

## Architecture

```
Sources/SenseLayer/
├── Models/              Domain types (immutable, hashable)
│   ├── BrailleCell              6-dot braille representation
│   ├── Message                  Username, body, category, tone, urgency, timestamp
│   ├── MessageCategory          .urgent, .personal, .work, .other
│   ├── SenseMode                .home, .navigate(context), .read(context)
│   ├── Tone                      .neutral, .anger, .empathy, .urgent
│   ├── DemoScenario             Fraud alert, overload, relationships
│   └── HapticSignature          Event → haptic pattern mapping
│
├── Services/            Business logic (protocols, dependency injection)
│   ├── MessageRepository        Load all messages (protocol + mock)
│   ├── DraftStore              Save/load/clear conversation drafts
│   ├── SendService             Send message to recipient (protocol + mock)
│   ├── CompressionService      Categorize, detect tone, score urgency, summarize
│   └── MockMessageFactory      Seed-based deterministic message generation
│
├── State/               Observable state machine (generic over Haptics)
│   ├── SenseLayerState<HapticService>  Core state machine (see separate section)
│   └── AppState                        Typealias: SenseLayerState<CoreHapticService>
│
├── Haptics/             Haptic abstraction layer
│   ├── HapticEngine     Protocol for all haptic playback (play event, start/stop tactile reading)
│   ├── CoreHapticService        Real haptics (CHHapticEngine-backed)
│   ├── NoOpHapticService        Fallback for devices without haptics
│   └── TactileEngine    Per-character dot-pattern burst generation
│
├── Utilities/
│   ├── BrailleMapping          6-dot bitmask ↔ ASCII character mapping (Grade 1 braille)
│   ├── Scheduler               Cancellable timer for inactivity auto-exit
│   └── Extensions              String/character utility methods
│
└── Views/               SwiftUI UI (gesture-driven, state-observing)
    ├── ContentView              App entry point
    ├── BrailleAccessOverlayView Main view (1000+ lines, handles all modes)
    ├── BrailleDotsView         Renders 6-dot cells as visual circles
    ├── BrailleTextDotsView     Convenience: text → braille dots
    └── OverlaySubViews         Modal views (app launcher, braille notes, etc.)
```

### Key Design Decisions

**1. Pure Logic, UI Last**
- All state transitions, draft persistence, send behavior, braille mapping are unit-tested without UI.
- SenseLayerState is deterministic; all logic lives in a plain Swift struct.
- Views observe @Published state and react to changes.

**2. Dependency Injection for Testing**
- `SenseLayerState` is generic over `HapticService: ...protocol`.
- Tests inject `SpyHapticService` and assert exact haptic event sequences.
- `SendService`, `MessageRepository`, `Scheduler` are all protocols with mock impls.

**3. Haptics Only on Braille Dots**
- `BrailleAccessOverlayView` computes exact pixel width of rendered braille content.
- Drag gesture only fires haptics when finger is over dot area, not entire row.
- Prevents spurious haptic events on labels or padding.

**4. Per-Character Tactile Fingerprints** (Future: Full Implementation)
- Each braille cell's 6-dot bitmask drives a unique burst pattern.
- Not just intensity variation, but pulse count, timing gaps, per-dot-position intensity.
- Example: "a" (dot 1) = single sharp pulse; "l" (dots 1,2,3,4,5) = cascade.

**5. No Interruption During Reading**
- `readingMode` can be `.summary` (quick preview) or `.full` (deep content).
- Entering full mode sets a persistent flag; requires explicit exit tap.
- Urgent queue suspends deliveryuntil user exits normal read flow.

---

## state Machine

### Modes

```
          .home
            ↓↑
       .navigate
            ↓↑
          .read
           ↕
      isComposing
```

**Definitions:**

| Mode | Purpose | Context |
|---|---|---|
| `.home` | Dashboard (Messages, Notifications, Close actions) | — |
| `.navigate(context)` | List navigation (apps, conversations, items) | NavigateContext |
| `.read(context)` | Message reading + compose (with isComposing flag) | ReadContext |

### Transitions

| From | To | Trigger | Effect |
|---|---|---|---|
| — | `.home` | `enterMode()` | Load messages, activate |
| `.home` | `.navigate(.conversations(...))` | Double-tap Messages | Browse message senders |
| `.navigate` | `.read(...)` | Double-tap sender | Enter message reading |
| `.read` (summary) | `.read` (full) | Long-press | Stream full message |
| `.read` | compose | `startReply()` on double-tap | Show 6-dot keyboard |
| compose | `.read` | Save draft + `takeMeBack()` | Exit without sending |
| compose | `.read` | `sendDraft()` success | Send, clear draft, return |
| `.read` | `.navigate` | `takeMeBack()` | Return to conversation list |
| `.navigate` | `.home` | `takeMeBack()` | Return to dashboard |
| `.read`/`.navigate` | — | `exitMode()` + 60s inactivity | Deactivate, cleanup |

### Key Methods

```swift
// Activation
public func enterMode()                // Load messages, enter .home

// Navigation
public func enterNavigateMode(_ context: NavigateContext)
public func enterReadMode(_ context: ReadContext)
public func takeMeBack()               // Intelligent back: compose→read, read→navigate, etc.
public func exitMode()                 // Deactivate, cleanup, autosave drafts

// Reading
public func enterFullMode()            // Switch to .full reading
public func exitFullMode()

// Composing
public func startReply()               // Enter compose mode, load draft
public func commitBrailleChar()        // Dot mask → character
public func commitSpace()
public func deleteLastChar()
public func sendDraft() async          // Send, update state, haptic feedback

// Urgency
public func toggleUrgentOnly()         // Filter to .urgent category only
public func fraudFreezeCard()          // Fraud alert scenario transitions

// Tactile Reading (Stream braille characters)
public func beginTactileReading()
public func updateTactileReading(dotCount: Int)
public func stopTactileReading()

// Inactivity
private func resetInactivityTimer()    // 60s auto-exit after last interaction
```

### Published State

All changes to these trigger UI re-render:

```swift
@Published public var isActive: Bool
@Published public var currentMode: SenseMode
@Published public var activeCategoryIndex: Int
@Published public var activeMessageIndex: Int
@Published public var readingMode: ReadingMode  // summary vs full
@Published public var isComposing: Bool
@Published public var currentDraft: String
@Published public var lastSendResult: SendResult?
@Published public var judgeMode: Bool           // Show English labels (for sighted observers)
@Published public var demoScenario: DemoScenario?
@Published public var fraudAlertPhase: FraudAlertPhase?  // alert → frozen → calling
```

---

## Development Phases

### Phase 0 — Foundation ✓
- Project structure, models, unit test scaffold
- Core domain types (Message, Category, Tone)
- Mock data generator (deterministic, repeatable)

### Phase 1 — Semantic Intelligence ✓
- CompressionService: categorization, tone detection, urgency scoring, summaries
- Rule-based (no LLM in MVP)
- Full test coverage (120+ tests)

### Phase 2 — State Machine ✓
- SenseLayerState with all transitions
- Draft persistence (DraftStore)
- Inactivity timer (Scheduler)
- 100+ tests for all edge cases

### Phase 3 — Haptic Layer ✓
- HapticEngine protocol (play events, tactile reading)
- CoreHapticService implementation
- TactileEngine for per-character bursts
- SpyHapticService for test assertions

### Phase 4 — Views & Gestures ✓
- BrailleAccessOverlayView (entire UI)
- Single tap → focus + preview
- Double tap → activate/send
- Vertical swipe → navigate rows
- Horizontal drag → tactile reading
- Long press → full message stream

### Phase 5 — Integration & Polish ✓
- Connect all layers (views → state → services → haptics)
- 310+ test suite (deterministic, full coverage)
- Fraud alert scenario demo
- Judge Mode (English labels for sighted observers)

### Phase 6 — Production Readiness (Roadmap)
- Real iMessage/SMS integration
- Apple Intelligence (on-device LLM compression)
- HealthKit cognitive health tracking
- Apple Watch urgency layer
- Multimodal notification federation

---

## Sprint Breakdown

Each sprint builds incrementally. All work is test-driven.

### Sprint 1 — Foundation & Models (Checkpoint: Task 1-10)

**Models**
- [ ] Message model (UUID, sender, body, category, tone, urgency, timestamp, read flag)
- [ ] MessageCategory enum (.urgent, .personal, .work, .other)
- [ ] Tone enum (.neutral, .anger, .empathy, .urgent)
- [ ] Equatable/Hashable conformance for all types
- [ ] Unit tests for model invariants

**Mock Data**
- [ ] MockMessageFactory (seed-based deterministic generation)
- [ ] Tests for reproducibility (same seed → same messages)
- [ ] Integration test: repository returns factory messages

---

### Sprint 2 — Semantic Compression (Checkpoint: Task 11-25)

**Classification**
- [ ] Category keyword rules (urgent > work > personal > other)
- [ ] Tone detection rules (anger > empathy > urgent > calm)
- [ ] Urgency baseline scoring by category
- [ ] Keyword-based urgency boosts
- [ ] Clamp urgency 0…1

**Summary Generation**
- [ ] Truncate to 120 characters
- [ ] Remove newlines
- [ ] Preserve critical keywords
- [ ] Tests for edge cases (empty, single word, 200+ words)

**Testing**
- [ ] 50+ test cases for categorization
- [ ] 30+ test cases for tone detection
- [ ] 40+ test cases for urgency scoring
- [ ] Edge cases: empty body, special chars, emojis

---

### Sprint 3 — State Machine (Checkpoint: Task 26-50)

**Core State**
- [ ] SenseLayerState implementation
- [ ] enterMode() / exitMode()
- [ ] Mode transitions (home ↔ navigate ↔ read)
- [ ] Draft loading/saving on transitions
- [ ] Inactivity timer (60s) with cancellation

**Compose Flow**
- [ ] startReply() → show keyboard
- [ ] commitBrailleChar() → mask→character
- [ ] deleteLastChar()
- [ ] sendDraft() → SendService call → haptic feedback

**Testing**
- [ ] State invariant tests (mode consistency)
- [ ] All transition paths (100+ tests)
- [ ] Draft persistence (save/load/clear)
- [ ] Inactivity timeout behavior
- [ ] Message sequencing (next/prev boundaries)

---

### Sprint 4 — Haptic Layer (Checkpoint: Task 51-70)

**Abstraction**
- [ ] HapticEngine protocol
- [ ] CoreHapticService (CHHapticEngine backed)
- [ ] NoOpHapticService (fallback)
- [ ] TactileEngine (per-dot burst patterns)

**Event Types**
- preview (single click)
- activate (enter action)
- focusChanged (boundary bump)
- categorySwitch (soft pulse)
- sendSuccess (strong pulse)
- sendFailure (error pattern)
- endOfCategory (triple pulse)
- enterFullMode (escalation pattern)
- urgentTriplePulse (fraud alert)

**Testing**
- [ ] SpyHapticService captures event sequence
- [ ] Verify exact haptic triggers on state transitions
- [ ] Test fallback on simulator (no CoreHaptics)

---

### Sprint 5 — Views & Interaction (Checkpoint: Task 71-100+)

**Gestures**
- [ ] Single tap on row → focus + preview haptic
- [ ] Double tap on row → activate (navigate/read/send)
- [ ] Vertical swipe up/down → cycle focus
- [ ] Horizontal drag on braille → tactile reading
- [ ] Long press on full message → stream content

**Modular Views**
- [ ] BrailleAccessOverlayView (main, 900+ lines, all modes)
- [ ] BrailleDotsView (dot grid renderer)
- [ ] OverlaySubViews (modal sheets: app launcher, notes, captions)
- [ ] BrailleTextDotsView (text→dots convenience)

**Modes**
- [ ] Home mode: Messages, Notifications, Close actions
- [ ] Navigate mode: List of apps, conversations, items
- [ ] Read mode: Summary row, full message row, action buttons (Reply, Next, Back)
- [ ] Compose mode: Draft display, 6-dot keyboard, commit/space/delete/send/back

**Testing**
- [ ] 50+ view tests (interaction, state binding)
- [ ] Gesture debounce logic verified
- [ ] Focus navigation correctness

---

## File Structure

```
.
├── App/
│   └── SenseLayerApp.swift              App entry point
├── Sources/SenseLayer/
│   ├── SenseLayer.swift                 Module namespace
│   ├── Models/
│   │   ├── BrailleCell.swift
│   │   ├── Message.swift
│   │   ├── MessageCategory.swift
│   │   ├── Tone.swift
│   │   ├── SenseMode.swift              (includes ReadContext, NavigateContext)
│   │   ├── HapticSignature.swift
│   │   └── DemoScenario.swift
│   ├── Services/
│   │   ├── MessageRepository.swift
│   │   ├── DraftStore.swift
│   │   ├── SendService.swift
│   │   ├── CompressionService.swift
│   │   └── MockMessageFactory.swift
│   ├── State/
│   │   ├── SenseLayerState.swift        (600+ lines, full state machine)
│   │   └── AppState.swift               (1 line typealias)
│   ├── Haptics/
│   │   ├── HapticEngine.swift           (protocol)
│   │   ├── CoreHapticService.swift      (real implementation)
│   │   └── TactileEngine.swift          (burst pattern generation)
│   ├── Utilities/
│   │   ├── BrailleMapping.swift         (6-dot bitmask ↔ char)
│   │   ├── Scheduler.swift              (timer protocol + system impl)
│   │   └── Extensions.swift
│   └── Views/
│       ├── ContentView.swift            (App root view)
│       ├── BrailleAccessOverlayView.swift  (Main UI, 1000+ lines)
│       ├── BrailleDotsView.swift        (Dot grid rendering)
│       └── OverlaySubViews.swift        (Modal sheets)
└── Tests/SenseLayerTests/               (310+ unit tests)
    └── [26 test files covering all layers]
```

---

## Building & Testing

### Prerequisites

- Xcode 26+
- Swift 6.2
- iOS 26+ target
- macOS 13+ (for building)

### Build

```bash
swift build
```

This compiles the SenseLayer library and test suite.

### Run Tests

```bash
swift test
```

Output: 310+ tests covering models, services, state machine, haptics, views, and integration.

### Run App (Xcode)

```bash
open SenseLayerApp.xcodeproj
# Select iOS Simulator or device
# Cmd+R to run
```

### Key Test Files & Coverage

| File | Purpose | Test Count |
|---|---|---|
| MessageTests.swift | Model invariants | 10 |
| CompressionServiceTests.swift | Categorization, tone, urgency, summary | 100 |
| BrailleMappingTests.swift | 6-dot bitmask ↔ char round-trips | 50 |
| SenseLayerStateTests.swift | All state transitions | 80 |
| DraftStoreTests.swift | Draft persistence | 15 |
| CoreHapticServiceTests.swift | Haptic event playback | 20 |
| BrailleAccessOverlayView (implicit) | Gesture handling, focus management | 30+ |
| IntegrationTests.swift | Full user journeys | 5 |
| **Total** | — | **310+** |

### Continuous Integration

CI would run:
1. `swift build` — Compilation check
2. `swift test` — Full test suite
3. Code coverage report (target: 85%+)
4. SwiftLint static analysis (once added)

---

## Next Steps (Roadmap)

### Short-term (MVP Completion)
- [x] Core state machine complete
- [x] Gesture detection and tactile feedback
- [x] Draft composition and sending
- [ ] Real SMS/iMessage integration (blocked on API)
- [ ] Custom braille keyboard layout (iteration 2)

### Medium-term (Production Release)
- [ ] Apple Intelligence integration (on-device LLM)
- [ ] HealthKit cognitive health tracking
- [ ] Multi-account support (SMS, email, iMessage, Slack)
- [ ] Stress-aware alert dampening
- [ ] Weekly sensory health summaries

### Long-term (Ecosystem Expansion)
- [ ] Apple Watch micro-haptic urgency layer
- [ ] iPad spatial braille input
- [ ] macOS desktop integration
- [ ] Cross-device draft sync (iCloud)
- [ ] Custom haptic pattern library (user personalization)

---

## Questions & Support

For development questions, see `README.md` for architectural overview and design rationale.

For user journey context, see `UserJourney.md`.

---

*SenseLayer: The Post-Visual Operating System.*
*Generated February 22, 2026. Current version: MVP 0.1.0*
