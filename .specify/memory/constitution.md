<!--
  Sync Impact Report
  Version change: 0.0.0 → 1.0.0 (initial ratification)
  Added principles:
    - I. Privacy by Default
    - II. Native Platform Citizen
    - III. Minimal Footprint
    - IV. Offline-First
    - V. Test-Driven
    - VI. YAGNI / Ship Simple
  Added sections:
    - Technical Constraints
    - Development Workflow
  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ (Constitution Check section references this file)
    - .specify/templates/spec-template.md ✅ (no changes needed — spec is technology-agnostic)
    - .specify/templates/tasks-template.md ✅ (no changes needed — task structure is generic)
  Follow-up TODOs: None
-->
# Drawl Constitution

## Core Principles

### I. Privacy by Default

Zero audio data MUST leave the user's device under any circumstance.
All speech-to-text processing MUST execute locally using on-device models.
No analytics, telemetry, or crash reporting that transmits voice content,
audio recordings, or transcription text is permitted. If observability is
added in the future, it MUST be limited to non-sensitive operational
metrics (e.g., session count, model load time) and MUST require explicit
user opt-in. This is the foundational trust contract with users.

### II. Native Platform Citizen

Drawl MUST use native macOS APIs (AppKit, AVFoundation, Accessibility,
ServiceManagement) — not Electron, web wrappers, or cross-platform
frameworks. The app MUST follow Apple Human Interface Guidelines for
menu bar apps, system permission dialogs, and preferences windows.
All macOS integration points (global hotkeys, text insertion, Launch at
Login, permission requests) MUST use the platform-idiomatic approach.
Rationale: deep OS integration is impossible without native APIs, and
users expect Mac apps to behave like Mac apps.

### III. Minimal Footprint

The app MUST be invisible until needed. No Dock icon, no main window
at rest. Idle memory MUST stay minimal (model can be unloaded after
inactivity). Launch-to-ready time MUST be under 5 seconds. Every new
feature MUST justify its resource cost — if a feature measurably
increases idle CPU, memory, or launch time without proportional user
value, it MUST be rejected or made opt-in.

### IV. Offline-First

Core transcription MUST function with zero network connectivity.
Network access is permitted ONLY for model downloads during first-run
onboarding or user-initiated model switches. If network disappears
mid-download, the app MUST retain partial progress and allow retry.
During active dictation, zero outbound network requests are permitted —
no exceptions.

### V. Test-Driven

Tests MUST be written before implementation (red-green-refactor).
XCTest is the primary test framework. Critical subsystems requiring
test coverage: audio capture pipeline, transcription engine integration,
text insertion via Accessibility APIs, global hotkey registration,
preferences persistence, and history retention/cleanup. Tests MUST be
independently runnable without hardware dependencies where possible
(mock audio input, mock AXUIElement targets).

### VI. YAGNI / Ship Simple

Build the smallest working implementation first. No premature
abstraction layers, plugin architectures, or generic frameworks.
Concrete examples of YAGNI enforcement:
- One model runtime (whisper.cpp or CoreML — not both) until user
  feedback demands alternatives.
- One text insertion method until edge cases prove a second is needed.
- One indicator style (configurable position only) until users request
  visual customization.
- Preferences stored in UserDefaults — no custom database until scale
  demands it.
Complexity MUST be justified by a concrete, current user need — not
speculative future requirements.

## Technical Constraints

- **Language**: Swift 5.9+ (macOS native)
- **Minimum deployment target**: macOS 13 (Ventura)
- **Build system**: Xcode / Swift Package Manager
- **Testing**: XCTest
- **ML runtime**: whisper.cpp (C++ with Swift bridging) or CoreML
  (choose one per Principle VI)
- **Storage**: UserDefaults for preferences; local JSON or SQLite for
  transcription history
- **Distribution**: Direct download (DMG/ZIP) for v1; Mac App Store
  considered for v2

## Development Workflow

- All code changes MUST have corresponding tests (Principle V).
- All PRs/reviews MUST verify constitution compliance.
- Features that violate Minimal Footprint (Principle III) MUST include
  benchmark measurements justifying the resource cost.
- Any proposal to add network access beyond model downloads MUST be
  reviewed against Privacy by Default (Principle I) and requires
  explicit user consent documentation.

## Governance

This constitution supersedes all other development practices for the
Drawl project. Amendments require:
1. Written proposal documenting the change and rationale.
2. Impact assessment on existing principles (no silent contradictions).
3. Version bump following semantic versioning (MAJOR for principle
   removal/redefinition, MINOR for additions, PATCH for clarifications).

All implementation decisions MUST be traceable to a constitutional
principle. Complexity MUST be justified (see Complexity Tracking in
plan.md).

**Version**: 1.0.0 | **Ratified**: 2026-06-24 | **Last Amended**: 2026-06-24
