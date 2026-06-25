# UI Contracts: Drawl

**Feature**: `001-voice-transcription-app`
**Date**: 2026-06-25

This document defines the internal UI contracts for the Drawl macOS desktop app.
Since Drawl has no external API (it's a self-contained desktop application), these
contracts define the interfaces between internal components.

## Menu Bar Contract

The menu bar dropdown (NSStatusItem menu) exposes these items:

| Item | Type | Condition | Action |
|------|------|-----------|--------|
| Status indicator | Label | Always | Shows "Idle", "Listening…", or "Setup Required" |
| Separator | — | Always | — |
| Start/Stop Dictation | Button | Setup complete | Toggles dictation (alternative to hotkey) |
| Transcription History | Button | Setup complete | Opens history window |
| Separator | — | Always | — |
| Preferences… | Button | Always | Opens preferences window |
| Quit Drawl | Button | Always | Terminates the app |

## Setup Wizard Contract

Sequential steps, each must complete before advancing:

| Step | Title | Requirement | Detection | Recovery |
|------|-------|-------------|-----------|----------|
| 1 | Microphone Access | `AVCaptureDevice.authorizationStatus(for: .audio) == .authorized` | Poll after user grants | "Open System Settings" button |
| 2 | Accessibility Access | `AXIsProcessTrusted() == true` | Poll every 1s after user opens System Settings | "Open System Settings" button + instruction text |
| 3 | Download Model | Selected model file exists at expected local path | Progress bar (URLSession download task) | Retry button, cancel button, model tier picker |

## Indicator Overlay Contract

The floating indicator window (NSPanel):

| Property | Value |
|----------|-------|
| Level | NSWindow.Level.floating (always on top) |
| Size | 48×48 points (retina) |
| Style | Borderless, transparent background |
| Position | Configurable: near cursor or fixed corner |
| Animation | Idle: subtle pulse (opacity 0.6–1.0, 1.5s cycle) |
| Animation | Audio detected: waveform/pulse scaled by audio level |
| Appearance | Fade in: 200ms ease-in, Fade out: 300ms ease-out |
| Click-through | Yes (ignores mouse events) |
| Shows in Mission Control | No |

## Preferences Window Contract

| Setting | Control Type | Default | Persisted Key |
|---------|-------------|---------|---------------|
| Hotkey | Shortcut recorder | ⌥+Space | `hotkeyKeyCode` + `hotkeyModifiers` |
| Model | Dropdown (with download status) | Base | `selectedModelId` |
| Language | Dropdown | English | `language` |
| Indicator position | Segmented control | Near cursor | `indicatorPosition` |
| Launch at Login | Toggle | Off | `launchAtLogin` |

## History Window Contract

| Element | Behavior |
|---------|----------|
| List | Reverse-chronological, grouped by date |
| Entry | Shows: truncated text (first 100 chars), timestamp, source app name, duration |
| Copy button | Per-entry, copies full text to clipboard |
| Search | Filters entries by text content (case-insensitive) |
| Empty state | "No transcriptions yet. Hold ⌥+Space to start dictating." |
| Auto-cleanup | Entries older than 30 days not displayed and purged on app launch |

## Internal Service Protocols

### TranscriptionEngineProtocol
```swift
protocol TranscriptionEngineProtocol {
    func loadModel(at path: URL) async throws
    func transcribe(audioSamples: [Float], sampleRate: Int) async throws -> String
    func unloadModel()
    var isModelLoaded: Bool { get }
}
```

### HotkeyManagerProtocol
```swift
protocol HotkeyManagerProtocol {
    var onHotkeyDown: (() -> Void)? { get set }
    var onHotkeyUp: (() -> Void)? { get set }
    func register(keyCode: UInt16, modifiers: UInt64) throws
    func unregister()
}
```

### TextInsertionServiceProtocol
```swift
protocol TextInsertionServiceProtocol {
    func insertText(_ text: String) async throws
    func canInsertIntoFocusedElement() -> Bool
}
```

### ModelManagerProtocol
```swift
protocol ModelManagerProtocol {
    func availableModels() -> [SpeechModel]
    func download(model: SpeechModel, progress: @escaping (Float) -> Void) async throws
    func delete(model: SpeechModel) throws
    func localPath(for model: SpeechModel) -> URL?
}
```
