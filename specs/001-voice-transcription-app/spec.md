# Feature Specification: Drawl — Local Voice-to-Text Desktop App

**Feature Branch**: `001-voice-transcription-app`  
**Created**: 2026-06-24  
**Status**: Draft  
**Input**: User description: "Build a macOS desktop app (SuperWhisper clone) that runs in the background, does live transcription using a local on-device model, automatically types into active inputs via hotkey activation, with a small visual indicator during transcription."

## Clarifications

### Session 2026-06-24

- Q: What is the hotkey activation mode — hold-to-talk or toggle? → A: Hold-to-talk (hold ⌥+Space to dictate, release to stop).
- Q: Are speech models bundled with the app or downloaded on first launch? → A: Downloaded on first launch; app ships lightweight and prompts user to download chosen model.
- Q: How should the app handle Accessibility and Microphone permission onboarding? → A: First-run setup wizard walks user through Microphone → Accessibility → Model download before first use.
- Q: Should streaming transcription show live partial text or only insert finalized segments? → A: Insert finalized segments only; text appears in ~2–5 second bursts but never changes once inserted.
- Q: How long should transcription history be retained? → A: Last 30 days, with automatic cleanup of older entries.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Hotkey-Activated Dictation (Priority: P1)

A user is typing an email in any application. They hold down the global hotkey (⌥ + Space) to activate voice dictation. A small floating visual indicator appears on screen confirming the app is listening. The user speaks naturally, and transcribed text appears in the currently focused text field in real time. When the user releases the hotkey, dictation stops and the indicator disappears.

**Why this priority**: This is the core value proposition — replacing keyboard typing with voice input in any app on macOS. Without this, there is no product.

**Independent Test**: Can be fully tested by pressing the hotkey in any text field (Notes, Safari, Slack) and verifying spoken words appear as typed text. Delivers immediate value as a standalone feature.

**Acceptance Scenarios**:

1. **Given** the app is running in the background and a text field is focused, **When** the user presses ⌥ + Space and speaks "Hello world", **Then** "Hello world" appears in the focused text field within 1 second of speech completing.
2. **Given** dictation is active, **When** the user releases the ⌥ + Space hotkey, **Then** dictation stops and the visual indicator disappears.
3. **Given** dictation is active, **When** the user speaks continuously for 60 seconds, **Then** finalized text segments are progressively inserted into the text field in ~2–5 second bursts as they are confidently transcribed; once inserted, text does not change.
4. **Given** no text field is focused, **When** the user presses the hotkey, **Then** the app copies the transcribed text to the clipboard and shows a brief notification.

---

### User Story 2 — Background Menu Bar App (Priority: P1)

A user launches the app. It starts as a menu bar (status bar) application with no main window, running quietly in the background. The menu bar icon provides access to start/stop, preferences, and quit. The app launches at login if the user enables this preference.

**Why this priority**: The app must be unobtrusive and always available. A background menu bar presence is essential for the hotkey activation flow to work.

**Independent Test**: Can be tested by launching the app and confirming it appears only in the menu bar, with no Dock icon and no main window. Menu bar dropdown shows status and controls.

**Acceptance Scenarios**:

1. **Given** the app is launched, **When** the user looks at the screen, **Then** the app appears as a small icon in the macOS menu bar (no Dock icon, no main window).
2. **Given** the app is in the menu bar, **When** the user clicks the menu bar icon, **Then** a dropdown appears showing: current status (idle/listening), start/stop toggle, preferences, transcription history link, and quit.
3. **Given** the user enables "Launch at Login" in preferences, **When** the Mac restarts, **Then** the app auto-starts and appears in the menu bar.

---

### User Story 3 — Visual Transcription Indicator (Priority: P2)

When dictation is active, a small, unobtrusive floating overlay appears on screen — a subtle glowing orb, waveform animation, or pulsing dot — indicating the microphone is live. This overlay is always-on-top, semi-transparent, and positioned near the cursor or in a fixed corner. It disappears when dictation ends.

**Why this priority**: Users need immediate visual feedback that the app is listening. Without this, users cannot tell if their voice is being captured.

**Independent Test**: Can be tested by activating dictation and confirming a visual indicator appears, animates while audio is detected, and disappears when dictation ends.

**Acceptance Scenarios**:

1. **Given** dictation is activated via hotkey, **When** the app begins listening, **Then** a small floating indicator (animated orb/waveform) appears on screen within 200ms.
2. **Given** the indicator is visible, **When** the user's voice is detected, **Then** the indicator animates (e.g., pulses or shows waveform activity) to confirm audio is being captured.
3. **Given** dictation ends, **When** the hotkey is toggled off, **Then** the indicator fades out smoothly within 300ms.

---

### User Story 4 — On-Device Transcription with Local Model (Priority: P2)

All speech-to-text processing happens locally on the user's Mac using a lightweight on-device model (e.g., Whisper-based). No audio data is sent to external servers. The model loads quickly on app startup and transcribes in near-real-time.

**Why this priority**: Privacy and offline capability are core differentiators. Users must trust that their voice data stays on their device.

**Independent Test**: Can be tested by disconnecting from the internet, activating dictation, and confirming transcription still works. Network monitor confirms zero outbound audio traffic.

**Acceptance Scenarios**:

1. **Given** the app is running and the Mac is offline (no internet), **When** the user activates dictation and speaks, **Then** transcription works correctly with no degradation.
2. **Given** the app is freshly launched, **When** the local model finishes loading, **Then** the model is ready for transcription within 5 seconds of app launch.
3. **Given** the user speaks a sentence, **When** the model transcribes it, **Then** the transcription accuracy is at least 90% for clear English speech in a quiet environment.

---

### User Story 5 — Settings & Customization (Priority: P3)

A user opens the app's preferences (from the menu bar dropdown). They can customize the global hotkey, choose a transcription model size (tiny/base/small for speed vs. accuracy tradeoff), select input language, toggle launch-at-login, and adjust the visual indicator style/position.

**Why this priority**: Customization enhances usability but is not required for core functionality. A reasonable set of defaults makes the app usable without any configuration.

**Independent Test**: Can be tested by opening preferences, changing the hotkey binding, and verifying the new hotkey activates dictation.

**Acceptance Scenarios**:

1. **Given** the user opens preferences, **When** they change the hotkey from ⌥ + Space to ⌘ + Shift + V, **Then** the new hotkey activates dictation and the old one no longer works.
2. **Given** the user selects "small" model instead of "tiny", **When** they activate dictation, **Then** transcription uses the higher-accuracy model (with slightly higher latency).
3. **Given** the user changes the indicator position to "bottom-right corner", **When** dictation is next activated, **Then** the indicator appears in the bottom-right corner.

---

### User Story 6 — Transcription History (Priority: P3)

The user can view a log of recent transcriptions from the menu bar dropdown or a small history window. Each entry shows the transcribed text, timestamp, and a copy-to-clipboard button.

**Why this priority**: History provides a safety net — if text was transcribed but not inserted correctly, the user can recover it. Not essential for core flow.

**Independent Test**: Can be tested by performing several dictations, opening the history view, and confirming all transcriptions appear with timestamps and copy buttons.

**Acceptance Scenarios**:

1. **Given** the user has performed 5 dictations, **When** they open the history view, **Then** all 5 transcriptions appear in reverse-chronological order with timestamps.
2. **Given** a transcription entry is visible in history, **When** the user clicks the copy button, **Then** the transcription text is copied to the clipboard.

---

### Edge Cases

- What happens when the user activates dictation but no microphone is available or microphone permission is denied? → The app shows an alert with instructions to grant microphone access in System Settings and offers to re-open the setup wizard.
- What happens when Accessibility permission is not granted? → The app cannot insert text into other apps; it shows an alert explaining the requirement and directs the user to System Settings → Privacy & Security → Accessibility.
- What happens when the focused application does not accept text input (e.g., Finder desktop)? → The transcribed text is copied to the clipboard with a notification: "Text copied to clipboard."
- What happens if the user speaks in a language the model doesn't support well? → Transcription proceeds with best-effort output; the user can switch model/language in settings.
- What happens if the local model file is corrupted or missing? → The app displays an error with an option to re-download the model.
- What happens if the model download fails or is interrupted during first-run onboarding? → The app retains partial progress, shows a retry button, and explains the download is required before dictation can be used.
- What happens during very long dictation sessions (30+ minutes)? → The app continues transcribing with periodic auto-saves to history; memory usage stays bounded by processing in streaming chunks.
- What happens if another app registers the same global hotkey? → The app detects the conflict, notifies the user, and prompts them to choose an alternative hotkey.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST run as a macOS menu bar application with no Dock icon and no main window by default.
- **FR-002**: System MUST register a configurable global hotkey (default: ⌥ + Space) using a hold-to-talk model — holding the key activates dictation, releasing it stops dictation.
- **FR-003**: System MUST capture audio from the system's default microphone when dictation is activated.
- **FR-004**: System MUST transcribe captured audio to text using a local on-device speech recognition model with no network dependency.
- **FR-005**: System MUST insert transcribed text into the currently focused text field using OS-level text input simulation (as if typed by the user).
- **FR-006**: System MUST display a small floating visual indicator (overlay window) when dictation is active, showing listening/processing state.
- **FR-007**: System MUST support streaming/progressive transcription by inserting finalized text segments as they are confidently transcribed (in ~2–5 second bursts). Once text is inserted, it MUST NOT be modified or rewritten. No speculative/partial text is inserted into the target app.
- **FR-008**: System MUST provide a preferences interface accessible from the menu bar dropdown for hotkey customization, model selection, language, and indicator settings.
- **FR-009**: System MUST persist user preferences across app restarts.
- **FR-010**: System MUST support "Launch at Login" as a user-configurable option.
- **FR-011**: System MUST maintain a searchable transcription history log with timestamps, retaining entries for the last 30 days and automatically deleting older entries.
- **FR-012**: System MUST copy transcribed text to clipboard when no text input field is focused.
- **FR-013**: System MUST request and handle macOS microphone permission gracefully, with user-friendly error messages if denied.
- **FR-014**: System MUST support at least 3 model size tiers (e.g., tiny, base, small) trading off speed for accuracy.
- **FR-015**: System MUST support English as the primary transcription language, with the architecture designed to accommodate additional languages.
- **FR-016**: System MUST provide a first-run setup wizard that sequentially guides the user through: (1) granting Microphone permission, (2) granting Accessibility permission, and (3) selecting and downloading a speech model — all before dictation can be used. Each step must include clear explanations of why the permission is needed, a button to open System Settings to the correct pane, and detection of whether the permission was successfully granted before advancing.
- **FR-017**: System MUST request and handle macOS Accessibility permission (System Settings → Privacy & Security → Accessibility) gracefully, with user-friendly guidance if denied, since text insertion into other apps is impossible without it.

### Key Entities

- **Transcription Session**: A single dictation activation-to-deactivation cycle; includes raw audio reference, transcribed text, timestamp, duration, and the target application name.
- **Speech Model**: The local ML model used for transcription; has attributes: name, size tier, file path, supported languages, and loaded/unloaded state.
- **User Preferences**: Configuration state including hotkey binding, selected model tier, language, indicator style/position, launch-at-login toggle.
- **Transcription History Entry**: A saved record of a completed transcription with text content, timestamp, source app, and duration. Entries are automatically purged after 30 days.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can activate dictation and see the first finalized text segment appear in the focused text field within 2–5 seconds of starting to speak.
- **SC-002**: Transcription works fully offline with zero network requests during dictation.
- **SC-003**: Transcription accuracy is at least 90% for clear English speech in a quiet environment.
- **SC-004**: The app's memory footprint stays below 500 MB during active transcription (including loaded model).
- **SC-005**: The app launches and the model is ready to transcribe within 5 seconds of startup.
- **SC-006**: The visual indicator appears within 200ms of hotkey activation.
- **SC-007**: Users can change the hotkey and have it take effect immediately without restarting the app.
- **SC-008**: The app handles continuous dictation sessions of at least 30 minutes without crashing or significant memory growth.

## Assumptions

- Target platform is macOS 13 (Ventura) or later, leveraging Apple's native APIs (AppKit, Accessibility).
- The app will be built as a native macOS application (Swift) for optimal system integration (global hotkeys, menu bar, accessibility API for text insertion).
- The local speech model will be based on OpenAI's Whisper architecture, using an optimized runtime (e.g., whisper.cpp or Apple's CoreML-converted variant) for on-device inference.
- Model files are downloaded on first launch (not bundled with the app); the app installer is lightweight (~10 MB). Users select and download their preferred model tier during first-run onboarding.
- Text insertion uses macOS Accessibility APIs (AXUIElement) or CGEvent-based keystroke simulation to type into the focused field.
- The app requires macOS Accessibility permission (System Settings → Privacy & Security → Accessibility) in addition to Microphone permission.
- Multi-language support beyond English is a future enhancement (v2); the architecture accommodates it but only English is fully supported in v1.
- The app name is "Drawl" (matching the repository name).
