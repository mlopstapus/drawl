# Tasks: Drawl — Local Voice-to-Text Desktop App

**Input**: Design documents from `specs/001-voice-transcription-app/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/ui-contracts.md, quickstart.md

**Tests**: Included — project constitution (Principle V: Test-Driven) requires tests before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **macOS app**: `Drawl/` for source, `DrawlTests/` for tests
- Organized by responsibility: `App/`, `Audio/`, `Transcription/`, `Input/`, `UI/`, `Storage/`, `Permissions/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the Xcode project, configure dependencies, and establish project skeleton

- [X] T001 Create Xcode project `Drawl.xcodeproj` with Swift app target `Drawl` and test target `DrawlTests`; set deployment target to macOS 13.0, set `LSUIElement=true` in Info.plist, disable App Sandbox in entitlements
- [X] T002 Add SPM dependency: whisper.cpp (`https://github.com/ggerganov/whisper.cpp`) and GRDB.swift (`https://github.com/groue/GRDB.swift`) via Xcode Package Dependencies
- [X] T003 [P] Create directory structure under `Drawl/`: `App/`, `Audio/`, `Transcription/`, `Input/`, `UI/`, `Storage/`, `Permissions/`, `Resources/Assets.xcassets`
- [X] T004 [P] Create directory structure under `DrawlTests/` mirroring source directories
- [X] T005 [P] Add `NSMicrophoneUsageDescription` and `NSAppleEventsUsageDescription` to `Drawl/App/Info.plist`
- [X] T006 [P] Create app entry point `Drawl/App/DrawlApp.swift` with `@main` and `NSApplication` setup as a menu bar-only app (no main window, `NSApp.setActivationPolicy(.accessory)`)

**Checkpoint**: Empty app runs, appears only in menu bar, no Dock icon

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational Phase

- [X] T007 [P] Write unit test for `PreferencesStore` in `DrawlTests/PreferencesStoreTests.swift`: test default values, read/write hotkey settings, read/write model selection, persistence across re-instantiation
- [X] T008 [P] Write unit test for `HistoryStore` in `DrawlTests/HistoryStoreTests.swift`: test insert entry, fetch entries sorted by date, search by text, delete entries older than 30 days, empty state

### Implementation for Foundational Phase

- [X] T009 [P] Implement `PreferencesStore` in `Drawl/Storage/PreferencesStore.swift`: UserDefaults wrapper with properties for `hotkeyKeyCode`, `hotkeyModifiers`, `selectedModelId`, `language`, `indicatorPosition`, `launchAtLogin`, `hasCompletedSetup`, `historyRetentionDays` with defaults per data-model.md
- [X] T010 [P] Implement `HistoryStore` in `Drawl/Storage/HistoryStore.swift`: SQLite persistence via GRDB.swift for `HistoryEntry` records — insert, fetch (reverse-chronological), search by text content, purge entries older than `historyRetentionDays`, count
- [X] T011 [P] Define enumerations in `Drawl/App/Models.swift`: `ModelTier` (tiny/base/small with display names and file sizes), `IndicatorPosition` (nearCursor, topRight, topLeft, bottomRight, bottomLeft), `AppState` (idle, listening, processing, setupRequired, modelDownloading, error)
- [X] T012 [P] Implement `MicrophonePermission` in `Drawl/Permissions/MicrophonePermission.swift`: check authorization status via `AVCaptureDevice.authorizationStatus(for: .audio)`, request access, provide observable `isGranted` property
- [X] T013 [P] Implement `AccessibilityPermission` in `Drawl/Permissions/AccessibilityPermission.swift`: check via `AXIsProcessTrusted()`, provide `openSystemSettings()` to deep-link to Accessibility pane, provide observable `isGranted` property with polling timer

**Checkpoint**: Foundation ready — preferences persist, history stores/queries, permissions can be checked. User story implementation can now begin.

---

## Phase 3: User Story 1 — Hotkey-Activated Dictation (Priority: P1) 🎯 MVP

**Goal**: User holds ⌥+Space → speaks → transcribed text appears in focused text field → releases key → dictation stops

**Independent Test**: Hold ⌥+Space in Notes.app, speak "Hello world", release. "Hello world" should appear in Notes.

### Tests for User Story 1

- [X] T014 [P] [US1] Write unit test for `HotkeyManager` in `DrawlTests/HotkeyManagerTests.swift`: test registration/unregistration of CGEvent tap, test callback invocation on simulated key-down and key-up events, test hotkey reconfiguration
- [X] T015 [P] [US1] Write unit test for `AudioCaptureManager` in `DrawlTests/AudioCaptureTests.swift`: test start/stop capture, test audio format conversion to 16kHz mono Float32, test buffer accumulation using mock audio input
- [X] T016 [P] [US1] Write unit test for `WhisperEngine` in `DrawlTests/WhisperEngineTests.swift`: test model loading from file path, test transcription of pre-recorded WAV audio samples, test unload, test `isModelLoaded` state
- [X] T017 [P] [US1] Write unit test for `TextInsertionService` in `DrawlTests/TextInsertionTests.swift`: test clipboard save/restore cycle, test paste simulation via CGEvent, test `canInsertIntoFocusedElement()` detection
- [X] T018 [P] [US1] Write unit test for `TranscriptionSession` in `DrawlTests/TranscriptionSessionTests.swift`: test session lifecycle (start → segments arrive → end), test finalized segment concatenation, test history entry creation on completion

### Implementation for User Story 1

- [X] T019 [US1] Implement `HotkeyManager` in `Drawl/Input/HotkeyManager.swift`: CGEvent tap that detects key-down (start dictation) and key-up (stop dictation) for configurable modifier+key combo; consume the event to prevent pass-through; expose `onHotkeyDown` and `onHotkeyUp` callbacks; support re-registration on hotkey change per `HotkeyManagerProtocol` from contracts
- [X] T020 [US1] Implement `AudioCaptureManager` in `Drawl/Audio/AudioCaptureManager.swift`: start/stop microphone capture via `AVAudioEngine.inputNode`, convert audio to 16kHz mono Float32 via `AVAudioConverter`, accumulate samples in a ring buffer, expose `onAudioBuffer` callback when segment threshold reached (~5 seconds or silence detected)
- [X] T021 [US1] Implement `AudioBufferProcessor` in `Drawl/Audio/AudioBufferProcessor.swift`: silence detection (RMS below threshold for >500ms triggers segment boundary), time-based segmentation (force segment at ~5s), buffer copy and reset for whisper.cpp consumption
- [X] T022 [US1] Implement `WhisperEngine` in `Drawl/Transcription/WhisperEngine.swift`: load GGML model file via whisper.cpp C API, run transcription on background thread, return finalized text string, unload model, implement `TranscriptionEngineProtocol` from contracts
- [X] T023 [US1] Implement `TextInsertionService` in `Drawl/Input/TextInsertionService.swift`: save current clipboard → set text to `NSPasteboard.general` → simulate ⌘V via `CGEvent` → restore clipboard after 100ms delay; implement `canInsertIntoFocusedElement()` via AXUIElement role check; fallback to clipboard-only with notification per FR-012; implement `TextInsertionServiceProtocol` from contracts
- [X] T024 [US1] Implement `TranscriptionSession` in `Drawl/Transcription/TranscriptionSession.swift`: orchestrate full dictation lifecycle — start audio capture on hotkey-down, feed segments to WhisperEngine, insert finalized text via TextInsertionService, stop on hotkey-up, create HistoryEntry and save to HistoryStore on completion
- [X] T025 [US1] Implement `AppDelegate` in `Drawl/App/AppDelegate.swift`: wire HotkeyManager, AudioCaptureManager, WhisperEngine, TextInsertionService, and TranscriptionSession together; manage AppState transitions; load model on app launch; handle permission checks before first dictation

**Checkpoint**: User Story 1 fully functional — hold ⌥+Space in any text field, speak, text appears. Core MVP complete.

---

## Phase 4: User Story 2 — Background Menu Bar App (Priority: P1)

**Goal**: App runs as a menu bar app with dropdown showing status, controls, and navigation

**Independent Test**: Launch app, confirm menu bar icon visible (no Dock icon), click icon, see status/controls dropdown

### Tests for User Story 2

- [X] T026 [P] [US2] Write unit test for `MenuBarController` in `DrawlTests/MenuBarControllerTests.swift`: test menu items present (status, preferences, history, quit), test status label updates based on AppState changes

### Implementation for User Story 2

- [X] T027 [US2] Implement `MenuBarController` in `Drawl/UI/MenuBarController.swift`: create `NSStatusItem` with system symbol icon, build `NSMenu` with items per menu bar contract (status label, separator, Start/Stop toggle, Transcription History, separator, Preferences…, Quit Drawl), update status label reactively based on AppState
- [X] T028 [US2] Wire `MenuBarController` into `AppDelegate` in `Drawl/App/AppDelegate.swift`: initialize on app launch, connect menu actions to TranscriptionSession start/stop, Preferences window, History window, and `NSApp.terminate`
- [X] T029 [US2] Implement Launch at Login in `Drawl/App/AppDelegate.swift`: use `ServiceManagement.SMAppService.mainApp` to register/unregister launch-at-login based on `PreferencesStore.launchAtLogin` preference

**Checkpoint**: App runs in menu bar, dropdown works, status updates in real-time, Launch at Login configurable.

---

## Phase 5: User Story 3 — Visual Transcription Indicator (Priority: P2)

**Goal**: Small animated floating overlay appears during dictation, animates with audio, disappears on stop

**Independent Test**: Hold ⌥+Space, see floating indicator appear within 200ms, see it animate while speaking, release key, indicator fades out within 300ms

### Tests for User Story 3

- [ ] T030 [P] [US3] Write unit test for `IndicatorWindow` in `DrawlTests/IndicatorWindowTests.swift`: test show/hide transitions, test positioning options (nearCursor, fixed corners), test window level is floating, test click-through behavior

### Implementation for User Story 3

- [ ] T031 [US3] Implement `IndicatorWindow` in `Drawl/UI/IndicatorWindow.swift`: borderless `NSPanel` at `.floating` level, 48×48pt, transparent background, click-through (`ignoresMouseEvents = true`), not shown in Mission Control; show with 200ms fade-in, hide with 300ms fade-out; position based on `IndicatorPosition` preference (near cursor via `NSEvent.mouseLocation` or fixed screen corner)
- [ ] T032 [US3] Implement indicator animation in `Drawl/UI/IndicatorWindow.swift`: idle pulse animation (opacity 0.6–1.0, 1.5s cycle) when listening but no audio; audio-reactive animation (scale/pulse intensity based on RMS audio level) when voice detected; use `CABasicAnimation` or `NSAnimationContext`
- [ ] T033 [US3] Wire `IndicatorWindow` into `TranscriptionSession` in `Drawl/Transcription/TranscriptionSession.swift`: show indicator on hotkey-down, update animation intensity from `AudioCaptureManager` audio level callback, hide indicator on hotkey-up

**Checkpoint**: Visual indicator visible during dictation, animates with audio, respects position preference.

---

## Phase 6: User Story 4 — On-Device Transcription with Local Model (Priority: P2)

**Goal**: Model management — download, select, and manage multiple Whisper model tiers; fully offline transcription

**Independent Test**: Disconnect from internet, hold ⌥+Space, speak, confirm transcription works. Reconnect, switch model tier in preferences.

### Tests for User Story 4

- [X] T034 [P] [US4] Write unit test for `ModelManager` in `DrawlTests/ModelManagerTests.swift`: test `availableModels()` returns 3 tiers, test download to `~/Library/Application Support/Drawl/Models/`, test `localPath()` resolution, test `delete()` removes file, test download progress reporting

### Implementation for User Story 4

- [X] T035 [US4] Implement `ModelManager` in `Drawl/Transcription/ModelManager.swift`: define 3 model tiers (tiny/base/small) with Hugging Face CDN download URLs and expected file sizes; download via `URLSession` with progress callback; store models in `~/Library/Application Support/Drawl/Models/`; validate downloaded file integrity (size check); implement `ModelManagerProtocol` from contracts
- [ ] T036 [US4] Implement model switching in `Drawl/Transcription/WhisperEngine.swift`: unload current model, load new model from `ModelManager.localPath()`, update `PreferencesStore.selectedModelId`; handle case where selected model is not yet downloaded
- [ ] T037 [US4] Add model download progress UI to `MenuBarController` in `Drawl/UI/MenuBarController.swift`: show download progress in menu bar dropdown when a model download is in progress; disable dictation until at least one model is downloaded

**Checkpoint**: Multiple model tiers available, download/switch works, transcription fully offline.

---

## Phase 7: User Story 5 — Settings & Customization (Priority: P3)

**Goal**: Preferences window for hotkey, model, language, indicator position, and launch-at-login

**Independent Test**: Open Preferences from menu bar, change hotkey to ⌘+Shift+V, verify new hotkey activates dictation and old one doesn't

### Tests for User Story 5

- [ ] T038 [P] [US5] Write unit test for preferences binding in `DrawlTests/PreferencesStoreTests.swift`: test that changing hotkey in preferences triggers `HotkeyManager.register()` with new key code and modifiers

### Implementation for User Story 5

- [ ] T039 [US5] Implement `PreferencesView` in `Drawl/UI/PreferencesView.swift`: macOS Settings window (SwiftUI or AppKit `NSWindow`) with sections per preferences contract — hotkey recorder (capture next key combination), model dropdown (with download status per tier), language dropdown (English only for v1, architecture for more), indicator position segmented control, launch-at-login toggle
- [ ] T040 [US5] Implement hotkey recorder in `PreferencesView`: custom control that enters "recording" mode on click, captures next key-down event (key code + modifiers), displays human-readable shortcut string (e.g., "⌥Space"), saves to `PreferencesStore`, triggers `HotkeyManager.unregister()` + `register()` with new binding immediately (per SC-007)
- [ ] T041 [US5] Wire model selection in `PreferencesView` to `ModelManager` and `WhisperEngine`: dropdown shows all tiers with download status (downloaded/not), selecting a non-downloaded model triggers download with progress, selecting a downloaded model switches the active model in `WhisperEngine`

**Checkpoint**: All preferences configurable, hotkey changes take effect immediately, model switching works.

---

## Phase 8: User Story 6 — Transcription History (Priority: P3)

**Goal**: Browsable, searchable history of past transcriptions with copy-to-clipboard

**Independent Test**: Perform 5 dictations, open History from menu bar, see all 5 in reverse-chronological order, copy one to clipboard

### Tests for User Story 6

- [ ] T042 [P] [US6] Write unit test for history display in `DrawlTests/HistoryStoreTests.swift`: test 30-day purge on fetch, test search filtering, test empty state

### Implementation for User Story 6

- [ ] T043 [US6] Implement `HistoryView` in `Drawl/UI/HistoryView.swift`: SwiftUI or AppKit window showing transcription entries in reverse-chronological list grouped by date; each entry shows truncated text (first 100 chars), timestamp, source app name, duration; per-entry copy button that copies full text to `NSPasteboard.general`; search bar for case-insensitive text filtering; empty state message per history contract
- [ ] T044 [US6] Implement 30-day auto-cleanup in `Drawl/Storage/HistoryStore.swift`: on app launch and on `HistoryView` open, call `purgeOldEntries()` to delete records where `timestamp` is older than `PreferencesStore.historyRetentionDays`
- [ ] T045 [US6] Wire History menu item in `MenuBarController` to open `HistoryView` window

**Checkpoint**: History browsable, searchable, copy works, old entries auto-purged.

---

## Phase 9: User Story — First-Run Setup Wizard (Priority: P1, from FR-016)

**Goal**: Guided first-run setup: Microphone → Accessibility → Model download

**Independent Test**: Delete app preferences (reset `hasCompletedSetup`), launch app, wizard appears with 3 steps, complete each step, wizard closes, app is ready for dictation

### Tests for Setup Wizard

- [ ] T046 [P] [US-Setup] Write unit test for setup flow in `DrawlTests/SetupWizardTests.swift`: test step progression (cannot advance without permission granted), test model download step triggers `ModelManager.download()`, test `hasCompletedSetup` set to true on completion

### Implementation for Setup Wizard

- [ ] T047 [US-Setup] Implement `SetupWizardView` in `Drawl/UI/SetupWizardView.swift`: 3-step sequential wizard per setup wizard contract — Step 1: Microphone permission (explanation + "Grant Access" button triggering `AVCaptureDevice.requestAccess`, poll for `isGranted`); Step 2: Accessibility permission (explanation + "Open System Settings" button linking to Accessibility pane, poll `AXIsProcessTrusted()` every 1s); Step 3: Model selection (tier picker + download with progress bar)
- [ ] T048 [US-Setup] Wire setup wizard into app launch in `Drawl/App/AppDelegate.swift`: on launch, check `PreferencesStore.hasCompletedSetup`; if false, show `SetupWizardView` as modal; on completion, set `hasCompletedSetup = true`, load selected model, transition to idle state
- [ ] T049 [US-Setup] Add "Re-run Setup" option accessible from error alerts (when permissions are missing) and Preferences menu

**Checkpoint**: First-run experience complete — new users guided through all required setup before first dictation.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T050 [P] Create app icon and indicator visual assets in `Drawl/Resources/Assets.xcassets` — menu bar icon (template image, 18×18pt), indicator orb graphic (48×48pt)
- [ ] T051 [P] Add error handling across all services: graceful recovery for model load failures, audio capture failures, text insertion failures; user-facing error alerts with recovery actions
- [ ] T052 [P] Add hotkey conflict detection in `HotkeyManager`: detect when CGEvent tap fails to register (another app holds the key), notify user via alert, prompt to choose alternative hotkey
- [ ] T053 Memory optimization: verify <500 MB footprint during active transcription with `base` model; profile with Instruments; add model unload after inactivity timeout if needed
- [ ] T054 Validate all acceptance scenarios from spec.md manually (run through each Given/When/Then)
- [ ] T055 Code signing and notarization: configure Xcode for Developer ID signing, create notarization workflow for DMG distribution
- [ ] T056 Run quickstart.md validation: follow quickstart guide from scratch on a clean machine, verify all steps work

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phases 3–9)**: All depend on Foundational phase completion
  - US1 (Phase 3): No dependencies on other stories — **MVP**
  - US2 (Phase 4): No dependencies on other stories (but benefits from US1 wiring)
  - US3 (Phase 5): Depends on US1 (needs TranscriptionSession for indicator wiring)
  - US4 (Phase 6): Depends on US1 (needs WhisperEngine for model switching)
  - US5 (Phase 7): Depends on US1 + US4 (needs HotkeyManager + ModelManager)
  - US6 (Phase 8): Depends on US1 (needs HistoryStore populated by sessions)
  - Setup Wizard (Phase 9): Depends on US4 (needs ModelManager for download step)
- **Polish (Phase 10)**: Depends on all desired user stories being complete

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models/protocols before services
- Services before UI integration
- Core implementation before cross-component wiring
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T003, T004, T005, T006)
- All Foundational tasks marked [P] can run in parallel (T007–T013)
- US1 tests (T014–T018) can all run in parallel
- US2, US3, US4 can start in parallel after Foundational (if US1 is not a strict gate)
- All Polish tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Write unit test for HotkeyManager in DrawlTests/HotkeyManagerTests.swift"
Task: "Write unit test for AudioCaptureManager in DrawlTests/AudioCaptureTests.swift"
Task: "Write unit test for WhisperEngine in DrawlTests/WhisperEngineTests.swift"
Task: "Write unit test for TextInsertionService in DrawlTests/TextInsertionTests.swift"
Task: "Write unit test for TranscriptionSession in DrawlTests/TranscriptionSessionTests.swift"

# Then implementation (some parallelizable):
Task: "Implement HotkeyManager in Drawl/Input/HotkeyManager.swift"        # [P]
Task: "Implement AudioCaptureManager in Drawl/Audio/AudioCaptureManager.swift"  # [P]
Task: "Implement WhisperEngine in Drawl/Transcription/WhisperEngine.swift"      # [P]
Task: "Implement TextInsertionService in Drawl/Input/TextInsertionService.swift" # [P]
# Then sequential (depends on above):
Task: "Implement TranscriptionSession"  # depends on all above
Task: "Implement AppDelegate wiring"    # depends on TranscriptionSession
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1 (Hotkey-Activated Dictation)
4. **STOP and VALIDATE**: Hold ⌥+Space in Notes.app, speak, verify text appears
5. Demo/validate core product value

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (Dictation) + US2 (Menu Bar) → Test independently → **MVP!**
3. Add US3 (Indicator) + US4 (Model Management) → Visual + model polish
4. Add US-Setup (Wizard) → First-run experience
5. Add US5 (Preferences) + US6 (History) → Full feature set
6. Polish → Release-ready

### Sequential Solo Developer Strategy

Phase 1 → Phase 2 → Phase 3 (MVP) → Phase 4 → Phase 9 → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 10

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Tests MUST fail before implementing (Constitution Principle V)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
