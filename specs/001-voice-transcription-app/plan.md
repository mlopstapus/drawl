# Implementation Plan: Drawl — Local Voice-to-Text Desktop App

**Branch**: `001-voice-transcription-app` | **Date**: 2026-06-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-voice-transcription-app/spec.md`

## Summary

Drawl is a native macOS menu bar application that provides hold-to-talk voice dictation
powered by a local Whisper-based speech model. Users hold ⌥+Space to dictate; transcribed
text is inserted into the currently focused text field via Accessibility APIs. All processing
is on-device (offline-first). The app includes a first-run setup wizard (permissions + model
download), a floating visual indicator during dictation, user-configurable preferences, and
a 30-day transcription history log.

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 15+)
**Primary Dependencies**: AppKit (menu bar + UI), AVFoundation (audio capture),
  Accessibility APIs (text insertion), whisper.cpp or CoreML (speech-to-text inference)
**Storage**: UserDefaults (preferences), SQLite via GRDB.swift or local JSON (transcription history)
**Testing**: XCTest (unit + integration), mock audio/accessibility targets
**Target Platform**: macOS 13 (Ventura) or later
**Project Type**: Native macOS desktop application (menu bar app)
**Performance Goals**: <5s model load, first text segment in 2–5s, <200ms indicator appearance
**Constraints**: <500MB memory (including loaded model), fully offline transcription,
  hold-to-talk activation, finalized-segment-only insertion
**Scale/Scope**: Single user, local machine, ~10 MB app installer (models downloaded separately)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Privacy by Default | ✅ PASS | All transcription on-device; no network during dictation; no telemetry |
| II. Native Platform Citizen | ✅ PASS | Swift + AppKit + native APIs; no Electron/web wrappers |
| III. Minimal Footprint | ✅ PASS | Menu bar app, no Dock icon, <500MB memory target, <5s launch |
| IV. Offline-First | ✅ PASS | Network only for model downloads; core works offline |
| V. Test-Driven | ✅ PASS | XCTest required; mock audio/accessibility in test plan |
| VI. YAGNI / Ship Simple | ✅ PASS | Single model runtime, single text insertion method, UserDefaults for prefs |

**Gate result**: ALL PASS — proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-voice-transcription-app/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal UI contracts for this app)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Drawl/
├── App/
│   ├── DrawlApp.swift           # App entry point (@main), menu bar setup
│   ├── AppDelegate.swift        # NSApplicationDelegate, permission checks
│   └── Info.plist               # LSUIElement=true (no Dock icon), permissions
├── Audio/
│   ├── AudioCaptureManager.swift    # AVAudioEngine microphone capture
│   └── AudioBufferProcessor.swift   # Convert audio buffers for whisper input
├── Transcription/
│   ├── WhisperEngine.swift          # whisper.cpp bridging / CoreML wrapper
│   ├── TranscriptionSession.swift   # Session lifecycle (start → segments → end)
│   └── ModelManager.swift           # Model download, storage, selection, validation
├── Input/
│   ├── HotkeyManager.swift          # Global hotkey registration (hold-to-talk)
│   └── TextInsertionService.swift   # Accessibility/CGEvent text insertion
├── UI/
│   ├── MenuBarController.swift      # NSStatusItem menu bar dropdown
│   ├── IndicatorWindow.swift        # Floating overlay (always-on-top, animated)
│   ├── SetupWizardView.swift        # First-run wizard (permissions + model)
│   ├── PreferencesView.swift        # Settings window
│   └── HistoryView.swift            # Transcription history list
├── Storage/
│   ├── PreferencesStore.swift       # UserDefaults wrapper
│   └── HistoryStore.swift           # Transcription history persistence + 30-day cleanup
├── Permissions/
│   ├── MicrophonePermission.swift   # Microphone access check/request
│   └── AccessibilityPermission.swift # Accessibility access check/guidance
└── Resources/
    └── Assets.xcassets              # App icon, indicator assets

DrawlTests/
├── AudioCaptureTests.swift
├── WhisperEngineTests.swift
├── TranscriptionSessionTests.swift
├── HotkeyManagerTests.swift
├── TextInsertionTests.swift
├── HistoryStoreTests.swift
└── PreferencesStoreTests.swift

whisper.cpp/                         # Git submodule or SPM dependency
```

**Structure Decision**: Single native macOS app target (`Drawl`) with modular source
directories organized by responsibility. No separate backend/frontend split — this is a
self-contained desktop application. Test target `DrawlTests` mirrors the source structure.
whisper.cpp included as a dependency (submodule or SPM package).

## Complexity Tracking

> No constitution violations detected — no justifications required.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| (none)    | —          | —                                    |
