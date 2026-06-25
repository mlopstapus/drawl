# Research: Drawl — Local Voice-to-Text Desktop App

**Date**: 2026-06-25
**Feature**: `001-voice-transcription-app`

## R1: Speech-to-Text Runtime

### Decision: WhisperKit (via argmax-oss-swift SPM package)

### Rationale
WhisperKit is a native Swift framework purpose-built for running Whisper models on Apple
platforms. It uses CoreML + Metal + Apple Neural Engine (ANE) for hardware-accelerated
inference, auto-downloads and manages models, and provides a clean async Swift API. It
requires macOS 14.0+ and Xcode 16+.

**However**, our spec targets macOS 13 (Ventura). WhisperKit requires macOS 14+.
Therefore we must either:
- (a) Raise minimum deployment target to macOS 14 (Sonoma), or
- (b) Use whisper.cpp instead (supports macOS 13+)

**Decision**: Use **whisper.cpp** via the `whisper.spm` Swift Package (`ggerganov/whisper.cpp`)
to maintain macOS 13 compatibility per spec. whisper.cpp is cross-platform, highly optimized
for Apple Silicon via Metal, actively maintained (MIT license), and has a proven SwiftUI
example in the official repo.

If macOS 13 support is later dropped, WhisperKit is the recommended migration path for
deeper Apple hardware integration.

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **WhisperKit** (argmax-oss-swift) | Native Swift, auto model management, ANE acceleration, clean API | Requires macOS 14+, Xcode 16+; violates our macOS 13 deployment target |
| **whisper.cpp** (ggerganov) ✅ | macOS 13+, Metal acceleration, MIT license, mature ecosystem, SPM support | C++ with Swift bridging needed, manual model management |
| **Apple Speech Framework** | Built-in, no dependencies | No Whisper models, less accurate for general dictation, no offline control |
| **CoreML direct** | Native Apple framework | Requires manual model conversion, more complex integration |

### Model Sizes (GGML format for whisper.cpp)

| Model | Parameters | Disk Size | RAM Usage | Relative Speed | English Accuracy |
|-------|-----------|-----------|-----------|----------------|-----------------|
| tiny | 39M | ~75 MB | ~125 MB | Fastest | Good (~88%) |
| base | 74M | ~142 MB | ~210 MB | Fast | Better (~91%) |
| small | 244M | ~466 MB | ~480 MB | Moderate | Best (~94%) |

**Default model**: `base` — best balance of speed, accuracy, and memory for the 500 MB
memory budget. `tiny` available for low-resource machines; `small` for maximum accuracy.

**Download source**: Hugging Face — `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{model}.bin`

### Streaming Transcription Strategy

whisper.cpp processes audio in segments (up to 30 seconds per chunk). For "streaming"
behavior with finalized segments:

1. Audio is captured continuously via AVAudioEngine
2. Audio buffer accumulates until a segment boundary (silence detection or ~5s timeout)
3. Segment is sent to whisper.cpp for transcription
4. Finalized text is inserted into the target app
5. Buffer resets for the next segment

This produces the "2–5 second burst" insertion behavior specified in the clarifications.

---

## R2: Global Hotkey — Hold-to-Talk

### Decision: CGEvent tap for key-down/key-up detection

### Rationale
Hold-to-talk requires detecting both key-down and key-up events globally (across all apps).
Two approaches exist:

1. **NSEvent.addGlobalMonitorForEvents** — receives copies of events; cannot swallow them
2. **CGEvent.tapCreate** — intercepts events; can consume them to prevent pass-through

We need CGEvent tap because:
- We must **consume** the ⌥+Space keystroke during dictation (otherwise it triggers
  Spotlight or types a space in the focused app)
- We need reliable key-up detection to stop dictation
- CGEvent tap gives full control over event lifecycle

### Requirements
- **Accessibility permission** required (checked via `AXIsProcessTrustedWithOptions`)
- App must be **code-signed**
- App must run **outside App Sandbox** (or use specific entitlements)
- Must handle the case where modifier keys (⌥) are held before Space is pressed

### Configurability
User-configurable hotkey stored in UserDefaults. The app re-registers the CGEvent tap
callback filter whenever the hotkey binding changes. Changes take effect immediately
without app restart (per SC-007).

### Libraries Considered

| Option | Pros | Cons |
|--------|------|------|
| **Raw CGEvent tap** ✅ | Full control, hold-to-talk support, event consumption | More code, manual Carbon/CGEvent handling |
| **KeyboardShortcuts** (Sindre Sorhus) | Clean API, widely used | Designed for toggle shortcuts, not hold-to-talk; no key-up detection |
| **MASShortcut** | Mature | Objective-C, no hold-to-talk support |
| **HotKey** (Sam Soffes) | Simple Swift API | No key-up detection |

**Decision**: Custom CGEvent tap implementation — none of the libraries support
hold-to-talk (key-down + key-up) pattern out of the box.

---

## R3: Text Insertion into Arbitrary Apps

### Decision: Clipboard + Paste simulation (primary), with AX API fallback

### Rationale
Two approaches for inserting text into any focused text field:

1. **Accessibility API (AXUIElement)**: Set `kAXValueAttribute` on focused element
   - Works for native AppKit text fields
   - Fails in Electron apps, web text areas, custom renderers, terminals

2. **Clipboard + CGEvent paste (⌘V)**: Copy text to NSPasteboard, simulate ⌘V
   - Works in virtually every app that supports paste
   - Used by Alfred, Keyboard Maestro, and similar tools
   - Downside: temporarily overwrites user's clipboard

### Strategy
1. Save current clipboard contents
2. Set transcribed text to NSPasteboard
3. Simulate ⌘V via CGEvent
4. Restore original clipboard contents after a brief delay (~100ms)

This approach is battle-tested and provides maximum compatibility across all macOS
applications including Electron apps (Slack, VS Code), web browsers, terminals, and
native apps.

### Detecting Non-Text-Input Targets
When no text field is focused (e.g., Finder desktop), the paste simulation would fail
silently. The app detects this by:
1. Querying `AXUIElementCopyAttributeValue` for `kAXFocusedUIElementAttribute`
2. Checking if the element's `kAXRoleAttribute` is a text-accepting role
3. If not, skip paste and leave text in clipboard with a notification (per FR-012)

### Requirements
- Accessibility permission required
- App must run outside App Sandbox

---

## R4: Audio Capture

### Decision: AVAudioEngine with input node tap

### Rationale
AVAudioEngine provides real-time audio capture from the default input device with
configurable format conversion. It converts to the format required by whisper.cpp
(16 kHz, mono, Float32 PCM) via an AVAudioConverter.

### Pipeline
1. `AVAudioEngine.inputNode` taps the default microphone
2. Audio format converted to 16 kHz mono Float32
3. Samples accumulated in a ring buffer
4. On segment boundary (silence detection or time threshold), buffer is copied and
   sent to whisper.cpp inference on a background thread
5. Result text is dispatched to main thread for insertion

### Requirements
- Microphone permission required (`AVCaptureDevice.requestAccess(for: .audio)`)
- `NSMicrophoneUsageDescription` in Info.plist

---

## R5: App Distribution & Sandboxing

### Decision: Direct download (DMG) without App Sandbox for v1

### Rationale
The app requires:
- CGEvent taps (global hotkey interception)
- Accessibility API access (text insertion)
- System-wide event monitoring

These capabilities are incompatible with the Mac App Sandbox. The app will be
distributed as a signed DMG with notarization for Gatekeeper compliance.

Mac App Store distribution can be evaluated for v2 if Apple provides sufficient
entitlements for accessibility-based tools.

---

## Summary of Decisions

| Area | Decision | Key Dependency |
|------|----------|---------------|
| Speech-to-text runtime | whisper.cpp via whisper.spm | SPM package |
| Model format | GGML (.bin files) | Hugging Face CDN |
| Default model | base (~142 MB, ~91% accuracy) | — |
| Global hotkey | Custom CGEvent tap | Accessibility permission |
| Text insertion | Clipboard + ⌘V simulation | Accessibility permission |
| Audio capture | AVAudioEngine | Microphone permission |
| App distribution | Signed DMG, notarized | Apple Developer account |
| App Sandbox | Disabled | Required for CGEvent + AX |
