# ARCHIVED: Tasks Breakdown

> **Note:** This document has been consolidated into [DEVELOPMENT.md](DEVELOPMENT.md). Please refer to that file for the latest sprint breakdown and task organization.

---

# SenseLayer --- Tasks Breakdown

Generated: 2026-02-22 04:38 UTC

------------------------------------------------------------------------

# Sprint 1 --- Foundation & Models

## Setup

-   [ ] Create SwiftUI project
-   [ ] Create folder structure (Models, Services, State, Views,
    Haptics, Tests)
-   [ ] Configure XCTest target

## Models

-   [ ] Implement Message model
-   [ ] Implement MessageCategory enum
-   [ ] Implement Tone enum
-   [ ] Add Equatable / Hashable conformance
-   [ ] Add unit tests for model integrity

## Mock Data

-   [ ] Build MockMessageFactory (deterministic seed-based generator)
-   [ ] Write tests for deterministic generation
-   [ ] Integrate into MessageRepository

------------------------------------------------------------------------

# Sprint 2 --- Semantic Compression Engine

## Classification

-   [ ] Implement category keyword rules
-   [ ] Implement tone detection rules
-   [ ] Write classification unit tests

## Summary Generation

-   [ ] Implement summary truncation logic (\<=120 chars)
-   [ ] Remove newline characters
-   [ ] Write summary edge-case tests

## Urgency Scoring

-   [ ] Implement baseline scoring by category
-   [ ] Add keyword-based boosts
-   [ ] Clamp values 0...1
-   [ ] Add scoring tests

------------------------------------------------------------------------

# Sprint 3 --- State Machine Architecture

## Core State

-   [ ] Implement SenseLayerState
-   [ ] Add enterMode() / exitMode()
-   [ ] Add nextCategory() / prevCategory()
-   [ ] Add nextMessage()
-   [ ] Add enterFullMode() / exitFullMode()
-   [ ] Add startReply()
-   [ ] Add deleteLastChar()
-   [ ] Add sendDraft() placeholder

## Testing

-   [ ] Unit tests for all transitions
-   [ ] Test end-of-category boundary
-   [ ] Test persistent full mode

------------------------------------------------------------------------

# Sprint 4 --- Haptic Layer

## Abstraction

-   [ ] Create HapticEvent enum
-   [ ] Create HapticService protocol
-   [ ] Implement NoOpHapticService
-   [ ] Implement CoreHapticService (guarded init)

## Wiring

-   [ ] Inject HapticService into state
-   [ ] Trigger haptics on: - categorySwitch - sendSuccess -
    sendFailure - endOfCategory - urgentQueuedAlert - enterFullMode

## Testing

-   [ ] SpyHapticService for unit tests
-   [ ] Validate correct event emission

------------------------------------------------------------------------

# Sprint 5 --- Reading UI

## Dashboard

-   [ ] Build ContentView
-   [ ] Add inactive/active toggle
-   [ ] Build SenseDashboardView

## Gestures

-   [ ] Swipe left/right → categories
-   [ ] Press & hold → full mode
-   [ ] Tap → exit full mode

## Braille Strip

-   [ ] Implement windowing function
-   [ ] Add unit tests for window logic
-   [ ] Add drag gesture for horizontal reading

------------------------------------------------------------------------

# Sprint 6 --- Compose Mode

## Compose Activation

-   [ ] Swipe down → startReply()
-   [ ] Present ComposeView

## Keyboard

-   [ ] Implement 6-dot mapping bitmask
-   [ ] Add sequential mode
-   [ ] Add chorded mode approximation
-   [ ] Backspace logic
-   [ ] Unit tests for mapping

------------------------------------------------------------------------

# Sprint 7 --- Send Flow

## SendService

-   [ ] Define SendService protocol
-   [ ] Create MockSendService
-   [ ] Wire sendDraft() async flow

## Feedback

-   [ ] Success → single pulse
-   [ ] Failure → segmented pulse
-   [ ] Preserve draft on failure

## Testing

-   [ ] Test success path
-   [ ] Test failure path
-   [ ] Confirm draft preservation

------------------------------------------------------------------------

# Sprint 8 --- Persistence & Safety

## Draft Store

-   [ ] Implement DraftStore
-   [ ] Save draft on exit
-   [ ] Restore draft when re-entering conversation
-   [ ] Unit tests

## Auto Exit

-   [ ] Implement inactivity timer (60 seconds)
-   [ ] Inject scheduler for testability
-   [ ] Unit tests for auto-exit behavior

------------------------------------------------------------------------

# Sprint 9 --- Urgency Queue

## Simulation

-   [ ] Implement receiveNewMessage()
-   [ ] Queue urgent messages silently

## Behavior

-   [ ] Trigger urgentQueuedAlert on category exit
-   [ ] Clear queue after acknowledgment

## Testing

-   [ ] Verify no interruption
-   [ ] Verify alert timing

------------------------------------------------------------------------

# Sprint 10 --- Demo Mode & QA

## Demo Mode

-   [ ] Add demo data toggle
-   [ ] Scripted walkthrough scenario

## QA Checklist

-   [ ] Operable without visual input
-   [ ] Operable without audio input
-   [ ] No infinite vibration loops
-   [ ] No state inconsistencies
-   [ ] No draft loss
-   [ ] Deterministic transitions

------------------------------------------------------------------------

# Definition of Done

The MVP is complete when:

-   [ ] User can navigate categories tactilely
-   [ ] Read summaries and full messages
-   [ ] Compose using hybrid braille keyboard
-   [ ] Send with tactile confirmation
-   [ ] Handle failures safely
-   [ ] Experience zero forced interruptions
-   [ ] Drafts are never lost
-   [ ] All critical state transitions are unit tested

------------------------------------------------------------------------

# Guiding Principles

-   Small, test-driven increments
-   No hidden state mutations
-   No blocking operations on main thread
-   Deterministic tactile language
-   Accessibility-first design

SenseLayer is built with precision, not speed.
