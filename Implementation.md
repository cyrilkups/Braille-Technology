# ARCHIVED: Implementation Plan

> **Note:** This document has been consolidated into [DEVELOPMENT.md](DEVELOPMENT.md). Please refer to that file for the latest technical implementation guide.

---

# SenseLayer --- Implementation Plan

Generated: 2026-02-22 04:37 UTC

------------------------------------------------------------------------

# 1. Overview

This document provides the step-by-step technical implementation guide
for the SenseLayer MVP. It is structured so a developer can begin
building immediately using SwiftUI, XCTest, and CoreHaptics.

The implementation follows: - Clean architecture - State-driven design -
Test-first development - Incremental feature integration

------------------------------------------------------------------------

# 2. Technical Stack

Platform: iOS\
Framework: SwiftUI\
State Management: ObservableObject\
Testing: XCTest\
Haptics: CoreHaptics (abstracted)\
AI (MVP): Rule-based compression

------------------------------------------------------------------------

# 3. Project Structure

SenseLayer/ │ ├── Models/ │ ├── Message.swift │ ├──
MessageCategory.swift │ └── Tone.swift │ ├── Services/ │ ├──
CompressionService.swift │ ├── MessageRepository.swift │ ├──
DraftStore.swift │ ├── SendService.swift │ └── MockMessageFactory.swift
│ ├── Haptics/ │ ├── HapticEvent.swift │ ├── HapticService.swift │ ├──
CoreHapticService.swift │ └── NoOpHapticService.swift │ ├── State/ │ └──
SenseLayerState.swift │ ├── Views/ │ ├── ContentView.swift │ ├──
SenseDashboardView.swift │ ├── MessageSummaryView.swift │ ├──
BrailleStripView.swift │ ├── ComposeView.swift │ └──
BrailleKeyboardView.swift │ └── Tests/

------------------------------------------------------------------------

# 4. Development Phases

## Phase 1 --- Domain Models

-   Implement Message model
-   Add category and tone enums
-   Ensure Equatable/Hashable
-   Add unit tests

## Phase 2 --- Semantic Compression

-   Deterministic keyword categorization
-   Tone detection rules
-   Urgency scoring
-   Summary generation (\<=120 characters)
-   Full unit test coverage

## Phase 3 --- Repository & Draft Storage

-   In-memory message storage
-   Read status tracking
-   Draft persistence by conversation
-   Unit tests for state mutation

## Phase 4 --- Haptic Abstraction Layer

-   Define HapticEvent enum
-   Create HapticService protocol
-   Implement NoOp service
-   Add CoreHaptics implementation
-   Ensure safe fallback behavior

## Phase 5 --- State Machine Implementation

SenseLayerState handles:

-   Activation / Exit
-   Category navigation
-   Message navigation
-   Summary vs Full mode
-   Compose mode
-   Delete last character
-   Send flow

All transitions must be tested deterministically.

## Phase 6 --- SwiftUI Interface

-   Minimal activation screen
-   Category dashboard
-   Gesture handling: Swipe Up → Enter/Exit Swipe Left/Right →
    Categories Press & Hold → Full mode Tap → Exit full Swipe Down →
    Reply Swipe Right → Send

UI must remain secondary to state logic.

## Phase 7 --- Braille Reading Engine

-   Offset-based substring windowing
-   Horizontal drag gesture
-   Summary/full switching
-   Pure function tests for window logic

## Phase 8 --- Braille Compose System

-   6-dot bitmask mapping
-   Sequential mode
-   Chorded mode (approximation)
-   Backspace handling
-   Unit tests for all mappings

## Phase 9 --- Send & Feedback Logic

-   Async send simulation
-   Success → Single strong pulse
-   Failure → Segmented pulse
-   Preserve draft on failure

## Phase 10 --- Inactivity & Auto Exit

-   60-second timer
-   Save draft on exit
-   Safe return to dashboard
-   Test using injected scheduler

## Phase 11 --- Urgent Queue System

-   Incoming message simulation
-   No interruption during reading
-   Alert only upon category exit
-   Clear acknowledgment behavior
-   Unit tests for timing logic

------------------------------------------------------------------------

# 5. Testing Strategy

## Unit Tests

-   Compression rules
-   Urgency scoring bounds
-   State transitions
-   Draft save/restore
-   Braille mapping correctness
-   Windowing algorithm correctness

## Integration Tests

-   Gesture → State → Haptic chain
-   Compose → Send → Confirmation
-   Full reading sequence

## Manual Validation Checklist

-   Operable without looking at screen
-   No reliance on audio
-   No infinite vibration loops
-   No accidental mode switching
-   Draft never lost unexpectedly

------------------------------------------------------------------------

# 6. Performance Constraints

-   Haptic events \< 300ms
-   No continuous vibration loops
-   State transitions \< 16ms
-   No blocking main thread during send

------------------------------------------------------------------------

# 7. Definition of Done (MVP)

The MVP is complete when:

-   User can activate SenseLayer
-   Navigate categories tactilely
-   Read compressed summaries
-   Enter and exit full mode
-   Compose with hybrid braille keyboard
-   Send messages with tactile confirmation
-   Handle failures safely
-   Experience zero forced interruptions

------------------------------------------------------------------------

# 8. Future Enhancements

-   On-device LLM compression
-   Personalization learning
-   Apple Watch haptic mirroring
-   HealthKit cognitive load metrics
-   Real SMS / iMessage integration

------------------------------------------------------------------------

# Final Principle

This system must always prioritize: State clarity. Cognitive respect.
Tactile determinism. Safety.

SenseLayer is not just accessible software. It is a sensory-first
architecture.
