# Office Health App PRD (Extracted)

Source: `/Users/ishworambition/Downloads/office_health_requirements.docx`

## Text

Office Health App

Product Requirements Document

Version 1.0 — MVP Scope

Product

Office Health — Micro SaaS

Platform

Android (Kotlin + Jetpack Compose)

Author

Ishwor Khadka

Status

Draft — Requirements Phase

1. Overview

Office Health is a free, Android-first personal health app for individual office workers. It requires no company purchase, no HR involvement, and no wearable hardware. The app targets three silent, data-validated problems that affect the majority of desk workers: back and neck pain from prolonged sitting, eye strain from continuous screen use, and burnout from unchecked sedentary time.

The USP is integration + context-awareness. Where existing apps address one behavior in isolation (posture OR breaks OR hydration), Office Health combines all three in a single, lightweight experience with smart scheduling that respects the user’s focus time and escalates notifications using real data — not generic guilt messaging.

1.1 Problem Summary

Research basis for this product:

Problem

Prevalence

Source

Back / neck pain from sitting

65% of desk workers

BackEmbrace / Nature 2025

Eye strain / CVS

71% of office workers

CarePlus Health Data Q2 2024

Job burnout

52% past year

NAMI 2024

Sedentary 80% of waking hours

Avg office worker

Alter Chiropractic / BLS 2024

Dyslipidemia / metabolic risk

48% in health screenings

CarePlus Q1 2024

46 min sleep deficit

No natural light workers

Journal of Clinical Sleep Medicine

2. Refined Design Decisions

The following decisions were made during the requirements refinement session and are locked for MVP.

Decision

Rationale

Walk-to-dismiss: 20–30 steps

Light enough to actually do at a desk, meaningful enough to constitute real movement. Mirrors Alarmy’s anti-dismiss mechanic without being punishing.

Step counter sensor for detection

No runtime permission required on Android. Uses TYPE_STEP_COUNTER or ActivityRecognition to skip the reminder if the user is already moving.

Escalation trigger: ignored breaks + sedentary time

Both signals are required. Ignoring one break may be intentional (meeting). Only escalate when break is ignored AND sedentary time threshold is crossed.

Posture check: manual tap only

Camera-based ML Kit scan is opt-in. Avoids the privacy concern of automatic camera access. User taps 'Check my posture' from the home screen.

Bad posture detected: play animation immediately

No intermediate notification. User tapped in — they want to act now. Show animated correction video directly.

Notification tone: data-driven

e.g. '90 min sedentary. Back strain risk up 12%.' Not 'Your back is getting worse.' Specific, not guilt. Matches the office worker persona who responds to metrics.

Exercise list: by body part

Neck, Back, Wrist, Eyes. Fast to scan, maps directly to the pain the user currently has. No time filtering in MVP.

Exercise tab: separate, always accessible

Not buried in break flow. User can open it anytime, not just after a posture check fails.

MVP: full scope, all modules at once

Break + walking dismissal, posture check + ML Kit, escalating notifications, exercise library. All four ship together.

3. Module A — Break & Movement

3.1 Break Scheduling

BRK-01 Schedule recurring break reminders during work hours (P0)

BRK-02 Detect if user is already active before firing notification (P0)

BRK-03 Display a full-screen break screen with a walking prompt (P0)

BRK-04 Require 20–30 steps to dismiss the break screen (P0)

BRK-05 Allow user to snooze once (5 min) per break instance (P1)

BRK-06 Log each break: completed, snoozed, or ignored (P0)

BRK-07 Respect user-defined work hours (e.g. 9am–6pm) (P1)

BRK-08 Pause reminders when device screen is off for > 10 min (P1)

3.2 Escalating Notification Logic

Condition A: User has ignored ≥2 consecutive break reminders

Condition B: Sedentary time ≥ 90 minutes

Escalation levels: Level 1 (90m), Level 2 (+30m), Level 3 (+30m)

Resets when a break is completed.

4. Module B — Posture Check (ML Kit)

PST-01 Home CTA (P0)

PST-02 Open front camera on tap (P0)

PST-03 Analyze posture using ML Kit Pose Detection (P0)

PST-04 Real-time skeleton overlay (P0)

PST-05 Scan only when user is stationary (P0)

PST-06 Classify posture (P0)

PST-07 If poor posture, play correction animation immediately (P0)

PST-08 Correction animation specific to issue (P1)

PST-09 After video, show relevant exercise shortcuts (P1)

PST-10 Log posture checks (P0)

5. Module C — Exercise Library

EXR-01 Dedicated Exercise tab (P0)

EXR-02 Organized by body part (P0)

EXR-03 5–10 exercises per body part in MVP (P0)

EXR-04 Exercise cards (P0)

EXR-05 Detail screen with animation + instructions (P0)

EXR-06 Timer + completion logs (P1)

EXR-07 Smart filter from posture issue (P1)

EXR-08 Favorites + Quick Access (P2)

7. Data Model

BreakLog, PostureLog, ExerciseLog as described in the PRD.

8. Open Questions

Home dashboard contents, onboarding structure, freemium split, weekly report design, DND/Focus Mode behavior, animation asset format.

