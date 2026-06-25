# Data Model: Drawl

**Feature**: `001-voice-transcription-app`
**Date**: 2026-06-25

## Entities

### TranscriptionSession

A single dictation activation-to-deactivation cycle.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| id | UUID | Unique session identifier | Primary key, auto-generated |
| text | String | Final concatenated transcribed text | Non-empty after completion |
| startedAt | Date | Timestamp when hotkey was pressed (dictation began) | Required |
| endedAt | Date | Timestamp when hotkey was released (dictation ended) | Required, ≥ startedAt |
| duration | TimeInterval | Computed: endedAt - startedAt | ≥ 0 |
| sourceApp | String? | Bundle identifier of the focused app at session start | Optional (nil if Finder desktop) |
| sourceAppName | String? | Display name of the focused app | Optional |
| modelTier | String | Model used for transcription (tiny/base/small) | Required, enum-like |
| segmentCount | Int | Number of finalized segments in this session | ≥ 1 |
| insertedViaClipboard | Bool | Whether text was clipboard-pasted (vs. no text field) | Default: false |

**Lifecycle**: Created → Recording → Transcribing → Completed → (auto-purged after 30 days)

### SpeechModel

A locally stored Whisper model file.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| id | String | Model identifier (e.g., "ggml-base") | Primary key |
| tier | ModelTier | Size tier: .tiny, .base, .small | Required, enum |
| displayName | String | Human-readable name (e.g., "Base — Balanced") | Required |
| fileName | String | File name on disk (e.g., "ggml-base.bin") | Required |
| fileSize | Int64 | Expected file size in bytes | Required |
| downloadURL | URL | Hugging Face CDN URL | Required |
| localPath | URL? | Path on disk if downloaded | nil if not yet downloaded |
| isDownloaded | Bool | Computed: localPath != nil && file exists | — |
| isActive | Bool | Whether this is the currently selected model | At most one active |

**Lifecycle**: Available → Downloading → Downloaded → Active → (can be deleted and re-downloaded)

### UserPreferences

User-configurable settings, persisted in UserDefaults.

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| hotkeyKeyCode | UInt16 | Virtual key code for the hotkey | 49 (Space) |
| hotkeyModifiers | UInt64 | Modifier flags (e.g., ⌥) | NSEvent.ModifierFlags.option |
| selectedModelId | String | Active model identifier | "ggml-base" |
| language | String | Transcription language code | "en" |
| indicatorPosition | IndicatorPosition | Where the visual indicator appears | .nearCursor |
| launchAtLogin | Bool | Start app on macOS login | false |
| hasCompletedSetup | Bool | Whether first-run wizard has been completed | false |
| historyRetentionDays | Int | Days to retain transcription history | 30 |

### HistoryEntry

Persisted record of a completed transcription (stored in SQLite or JSON).

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| id | UUID | Unique entry identifier | Primary key |
| text | String | Transcribed text content | Non-empty |
| timestamp | Date | When the transcription was completed | Required |
| sourceAppName | String? | Display name of the target app | Optional |
| duration | TimeInterval | How long the dictation session lasted | ≥ 0 |
| modelTier | String | Which model was used | Required |

**Retention**: Auto-purged when timestamp is older than `historyRetentionDays`.

## Enumerations

### ModelTier
```
enum ModelTier: String, CaseIterable {
    case tiny   // ~75 MB, fastest, ~88% accuracy
    case base   // ~142 MB, balanced, ~91% accuracy
    case small  // ~466 MB, best accuracy, ~94%
}
```

### IndicatorPosition
```
enum IndicatorPosition: String, CaseIterable {
    case nearCursor      // Float near the text cursor
    case topRight        // Fixed: top-right corner
    case topLeft         // Fixed: top-left corner
    case bottomRight     // Fixed: bottom-right corner
    case bottomLeft      // Fixed: bottom-left corner
}
```

### AppState
```
enum AppState {
    case idle                    // No dictation, waiting for hotkey
    case listening               // Hotkey held, capturing audio
    case processing              // Transcribing a segment
    case setupRequired           // First-run wizard not completed
    case modelDownloading(Float) // Downloading model (progress 0–1)
    case error(AppError)         // Error state with recovery action
}
```

## Relationships

```
UserPreferences ──references──▶ SpeechModel (via selectedModelId)
TranscriptionSession ──creates──▶ HistoryEntry (on session completion)
SpeechModel ──used by──▶ TranscriptionSession (via modelTier)
```

## State Transitions

### App Lifecycle
```
Launch → [hasCompletedSetup?]
  ├─ No  → SetupWizard → (Mic Permission → AX Permission → Model Download) → Idle
  └─ Yes → [Model loaded?]
       ├─ No  → Loading Model → Idle
       └─ Yes → Idle

Idle → [Hotkey pressed] → Listening → [Audio captured] → Processing
Processing → [Segment finalized] → Text Inserted → Listening (continue)
Listening → [Hotkey released] → Final Processing → Idle
```

### Model Lifecycle
```
Available → [User selects] → Downloading → [Complete] → Downloaded
Downloaded → [User activates] → Active
Active → [User switches model] → Downloaded
Downloaded → [User deletes] → Available
```
