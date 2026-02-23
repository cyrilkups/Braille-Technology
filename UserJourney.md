# SenseLayer --- User Journey Document

Generated: 2026-02-22 04:37 UTC

------------------------------------------------------------------------

# 1. Overview

This document maps the complete user journey for a deafblind user
interacting with the SenseLayer MVP. The journey prioritizes tactile
autonomy, cognitive safety, and zero visual/audio dependency.

------------------------------------------------------------------------

# 2. Primary Persona

Name: Alex\
Profile: Deafblind university student\
Goal: Read messages, respond independently, avoid cognitive overload.

Constraints: - Cannot rely on screen visuals - Cannot rely on audio
feedback - Needs clear tactile confirmations - Needs interruption-free
reading

------------------------------------------------------------------------

# 3. Journey Flow

## Stage 1 --- Activation

Trigger: Swipe up from the bottom edge.

System Response: - SenseLayer enters active mode. - Soft activation
pulse confirms entry. - Category dashboard becomes active.

User Emotion: - Oriented - In control

------------------------------------------------------------------------

## Stage 2 --- Category Navigation

User Action: Swipe left/right.

System Behavior: - Categories cycle sequentially. - Soft pulse confirms
each switch. - First message summary renders immediately as tactile
strip.

User Outcome: - Immediate access to structured information - No
scrolling required

------------------------------------------------------------------------

## Stage 3 --- Reading Summary

User Action: Slide finger horizontally across screen.

System Behavior: - Horizontal braille strip updates under finger. -
AI-compressed one-line summary displayed tactually.

User Outcome: - Rapid understanding of message meaning - Reduced
cognitive load

------------------------------------------------------------------------

## Stage 4 --- Deep Reading

User Action: Press and hold.

System Behavior: - System enters full-message mode. - Subtle tactile
confirmation. - Strip now reads full message body. - Mode persists until
explicit tap.

User Outcome: - Full autonomy over depth exploration - No accidental
exit

------------------------------------------------------------------------

## Stage 5 --- Automatic Message Progression

System Behavior: - When end of message reached → auto-load next
message. - When end of category reached → subtle triple pulse.

User Outcome: - Continuous reading flow - Clear boundary awareness

------------------------------------------------------------------------

## Stage 6 --- Replying

User Action: Swipe down.

System Behavior: - Compose mode activates instantly. - 6-dot braille
keyboard available immediately.

User Emotion: - Empowered - Independent

------------------------------------------------------------------------

## Stage 7 --- Typing

Sequential Mode: Tap dots → commit → character appended.

Chorded Mode: Select multiple dots → commit → character generated.

Delete: Shake device → remove last character.

User Outcome: - Flexible input system - Error correction available

------------------------------------------------------------------------

## Stage 8 --- Sending

User Action: Swipe right.

System Behavior: - SendService triggered. - On success → single strong
pulse. - On failure → segmented pulse pattern. - Draft preserved on
failure.

User Outcome: - Clear feedback - No ambiguity - No data loss

------------------------------------------------------------------------

## Stage 9 --- Urgent Message Handling

Scenario: New urgent message arrives during reading.

System Behavior: - Message queued silently. - No interruption. - Upon
exiting category → urgent pulse alert once.

User Outcome: - Focus maintained - Urgency respected without chaos

------------------------------------------------------------------------

## Stage 10 --- Inactivity Auto-Exit

Condition: 60 seconds no interaction.

System Behavior: - Draft saved. - Exit SenseLayer mode. - Safe return to
dashboard on next entry.

User Outcome: - Privacy protected - No accidental message exposure

------------------------------------------------------------------------

# 4. Edge Case Journeys

## Network Failure During Send

-   Segmented pulse plays.
-   Draft remains intact.
-   User remains in compose mode.

## Empty Category

-   Soft pulse + remain in dashboard.
-   No forced navigation.

## Long Message

-   Windowing algorithm handles overflow.
-   No performance drop.

------------------------------------------------------------------------

# 5. Emotional Journey Summary

Start: Oriented\
During Reading: Calm, focused\
During Compose: Empowered\
After Send: Reassured\
End State: Independent

------------------------------------------------------------------------

# 6. Accessibility Guarantees

-   No required visual elements
-   No required audio cues
-   No forced interruptions
-   Deterministic tactile language
-   Draft never lost unintentionally

------------------------------------------------------------------------

# Final Narrative

SenseLayer transforms the smartphone from a visual screen into a tactile
intelligence surface.

For the deafblind user: Interaction becomes spatial. Information becomes
structured. Emotion becomes physical.

This is not assistive technology. This is autonomy through design.
