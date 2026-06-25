# Quickstart: Drawl Development

**Feature**: `001-voice-transcription-app`
**Date**: 2026-06-25

## Prerequisites

- macOS 13 (Ventura) or later
- Xcode 15+ with Swift 5.9+
- Apple Developer account (for code signing and notarization)
- A working microphone

## Setup

### 1. Clone and Open

```bash
cd /Users/ben/repos/drawl
# Open in Xcode (project will be created during task implementation)
open Drawl.xcodeproj
```

### 2. Dependencies (Swift Package Manager)

The project uses SPM for dependency management. Key packages:

| Package | URL | Purpose |
|---------|-----|---------|
| whisper.spm | `https://github.com/ggerganov/whisper.cpp` | Speech-to-text inference engine |
| GRDB.swift | `https://github.com/groue/GRDB.swift` | SQLite wrapper for transcription history |

Add via Xcode: **File → Add Package Dependencies** → paste URL.

### 3. Configure Info.plist

```xml
<!-- Hide from Dock -->
<key>LSUIElement</key>
<true/>

<!-- Microphone permission -->
<key>NSMicrophoneUsageDescription</key>
<string>Drawl needs microphone access to transcribe your speech.</string>

<!-- Accessibility explanation (shown in System Settings) -->
<key>NSAppleEventsUsageDescription</key>
<string>Drawl needs accessibility access to type transcribed text into your apps.</string>
```

### 4. Disable App Sandbox

In the `.entitlements` file, set:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

Required for CGEvent taps (global hotkey) and Accessibility API (text insertion).

### 5. Grant Permissions (Development)

On first run during development:
1. **Microphone**: macOS will prompt automatically
2. **Accessibility**: Manually add Xcode (or the built app) in
   System Settings → Privacy & Security → Accessibility

### 6. Download a Test Model

```bash
# Download the tiny model for fast development testing (~75 MB)
mkdir -p ~/Library/Application\ Support/Drawl/Models
curl -L -o ~/Library/Application\ Support/Drawl/Models/ggml-tiny.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin
```

## Build & Run

```bash
# Build from command line
xcodebuild -project Drawl.xcodeproj -scheme Drawl -configuration Debug build

# Or just press ⌘R in Xcode
```

The app will appear in the menu bar (not the Dock). Click the menu bar icon to interact.

## Testing

```bash
# Run all tests
xcodebuild test -project Drawl.xcodeproj -scheme Drawl

# Or in Xcode: ⌘U
```

## Project Structure

```
Drawl/
├── App/           # Entry point, app delegate, Info.plist
├── Audio/         # Microphone capture, audio buffer processing
├── Transcription/ # whisper.cpp engine, session management, model manager
├── Input/         # Global hotkey (CGEvent), text insertion (clipboard+paste)
├── UI/            # Menu bar, indicator overlay, setup wizard, preferences, history
├── Storage/       # UserDefaults preferences, SQLite history store
├── Permissions/   # Microphone and Accessibility permission helpers
└── Resources/     # Assets (app icon, indicator visuals)

DrawlTests/        # XCTest unit and integration tests
```

## Key Development Workflows

### Testing Dictation
1. Build and run the app (⌘R)
2. Open Notes.app or any text editor
3. Hold ⌥+Space and speak
4. Release to stop — text should appear in the editor

### Testing Without Microphone
Mock audio input in tests using pre-recorded WAV files loaded into
the whisper.cpp engine directly. See `DrawlTests/WhisperEngineTests.swift`.

### Testing Text Insertion
The text insertion service can be tested by verifying clipboard contents
and CGEvent posting in a controlled environment. See
`DrawlTests/TextInsertionTests.swift`.
