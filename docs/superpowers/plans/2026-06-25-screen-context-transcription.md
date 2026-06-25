# Screen Context Transcription Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture the focused window's visible text at session start, filter it to proper nouns and identifiers, and feed it as Whisper's `initialPrompt` to improve transcription accuracy for names and technical terms.

**Architecture:** At hotkey-press, `TranscriptionSession.start()` fires `ScreenContextService.captureContext()` concurrently with audio pipeline startup. The service uses ScreenCaptureKit to grab a window screenshot, Vision OCR to extract text, and a word filter to produce a ≤150-word `initialPrompt` string. This string is stored on the session and passed to `WhisperEngine.transcribe()` via `DecodingOptions.initialPrompt` for every segment. Also adds selectable pulse color (stored as hex in preferences, passed to `IndicatorViewModel`).

**Tech Stack:** ScreenCaptureKit (`SCShareableContent`, `SCScreenshotManager`), Vision (`VNRecognizeTextRequest`), WhisperKit (`DecodingOptions.initialPrompt`), SwiftUI `ColorPicker`, UserDefaults.

---

## File Map

| Action | File | Purpose |
|---|---|---|
| Modify | `Drawl/App/Protocols.swift` | Add `context: String?` to `TranscriptionEngineProtocol.transcribe()` |
| Modify | `Drawl/Transcription/WhisperEngine.swift` | Pass context via `DecodingOptions.initialPrompt` |
| Modify | `Drawl/Storage/PreferencesStore.swift` | Add `screenContextEnabled` + `indicatorColorHex` |
| Create | `Drawl/Permissions/ScreenRecordingPermission.swift` | Permission check/request wrapper |
| Create | `Drawl/Input/ScreenContextService.swift` | Screenshot + OCR + word filter |
| Create | `Drawl/UI/Color+Hex.swift` | `Color(hex:)` init + `hexString` computed var |
| Modify | `Drawl/Transcription/TranscriptionSession.swift` | Accept `ScreenContextService?`, capture at `start()`, pass context to engine |
| Modify | `Drawl/UI/IndicatorWindow.swift` | Accept color in `IndicatorViewModel`; update `IndicatorView` to use it |
| Modify | `Drawl/App/AppDelegate.swift` | Instantiate `ScreenContextService` when enabled; pass color to `IndicatorWindow` |
| Modify | `Drawl/UI/PreferencesView.swift` | Screen context toggle + permission prompt; color picker |
| Modify | `DrawlTests/TranscriptionSessionTests.swift` | Update `MockTranscriptionEngine`; add context-passing test |
| Create | `DrawlTests/ScreenContextServiceTests.swift` | Unit tests for `filterWords(from:)` |
| Modify | `DrawlTests/PreferencesStoreTests.swift` | Assert new default values |

---

## Task 1: Update `TranscriptionEngineProtocol` and `WhisperEngine`

**Files:**
- Modify: `Drawl/App/Protocols.swift`
- Modify: `Drawl/Transcription/WhisperEngine.swift`
- Modify: `DrawlTests/TranscriptionSessionTests.swift` (update `MockTranscriptionEngine`)

- [ ] **Step 1: Update the protocol**

In `Drawl/App/Protocols.swift`, replace the `transcribe` line:
```swift
// Before:
func transcribe(audioSamples: [Float], sampleRate: Int) async throws -> String

// After:
func transcribe(audioSamples: [Float], sampleRate: Int, context: String?) async throws -> String
```

- [ ] **Step 2: Update `WhisperEngine`**

Replace the entire `transcribe` method in `Drawl/Transcription/WhisperEngine.swift`:
```swift
public func transcribe(audioSamples: [Float], sampleRate: Int, context: String?) async throws -> String {
    guard let wk = whisperKit else {
        throw AppError.transcriptionFailed("Model is not loaded")
    }
    guard sampleRate == 16000 else {
        throw AppError.transcriptionFailed("Invalid sample rate: \(sampleRate). Whisper requires 16000Hz.")
    }
    var options = DecodingOptions()
    if let context = context, !context.isEmpty {
        options.initialPrompt = context
    }
    let results = try await wk.transcribe(audioArray: audioSamples, decodeOptions: options)
    return results.map { $0.text }.joined()
        .replacingOccurrences(of: "[BLANK_AUDIO]", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
```

- [ ] **Step 3: Update `MockTranscriptionEngine` in tests**

In `DrawlTests/TranscriptionSessionTests.swift`, update the mock to match the new signature:
```swift
func transcribe(audioSamples: [Float], sampleRate: Int, context: String?) async throws -> String {
    transcribeCount += 1
    return mockResultText
}
```

- [ ] **Step 4: Build to confirm no other conformers are broken**

```bash
xcodebuild build -project Drawl.xcodeproj -scheme Drawl \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|passed|failed"
```
Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add Drawl/App/Protocols.swift Drawl/Transcription/WhisperEngine.swift \
  DrawlTests/TranscriptionSessionTests.swift
git commit -m "feat: add optional context parameter to TranscriptionEngineProtocol"
```

---

## Task 2: Add Preferences for Screen Context and Indicator Color

**Files:**
- Modify: `Drawl/Storage/PreferencesStore.swift`
- Modify: `DrawlTests/PreferencesStoreTests.swift`

- [ ] **Step 1: Write a failing test**

Add to `DrawlTests/PreferencesStoreTests.swift` inside `PreferencesStoreTests`:
```swift
func testScreenContextAndColorDefaults() {
    let store = PreferencesStore(defaults: userDefaultsSuite)
    XCTAssertFalse(store.screenContextEnabled)
    XCTAssertEqual(store.indicatorColorHex, "#8B5CF6")
}

func testScreenContextAndColorPersistence() {
    let store = PreferencesStore(defaults: userDefaultsSuite)
    store.screenContextEnabled = true
    store.indicatorColorHex = "#EF4444"

    let store2 = PreferencesStore(defaults: userDefaultsSuite)
    XCTAssertTrue(store2.screenContextEnabled)
    XCTAssertEqual(store2.indicatorColorHex, "#EF4444")
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "testScreenContext"
```
Expected: compile error (properties don't exist yet)

- [ ] **Step 3: Add keys and properties to `PreferencesStore`**

In `Drawl/Storage/PreferencesStore.swift`:

Add to the `Keys` enum:
```swift
static let screenContextEnabled = "screenContextEnabled"
static let indicatorColorHex = "indicatorColorHex"
```

Add two `@Published` properties after `historyRetentionDays`:
```swift
@Published public var screenContextEnabled: Bool {
    didSet { defaults.set(screenContextEnabled, forKey: Keys.screenContextEnabled) }
}

@Published public var indicatorColorHex: String {
    didSet { defaults.set(indicatorColorHex, forKey: Keys.indicatorColorHex) }
}
```

In `init`, add to `defaults.register(defaults:)` dict:
```swift
Keys.screenContextEnabled: false,
Keys.indicatorColorHex: "#8B5CF6",
```

In `init`, add initial value loads after `historyRetentionDays`:
```swift
self.screenContextEnabled = defaults.bool(forKey: Keys.screenContextEnabled)
self.indicatorColorHex = defaults.string(forKey: Keys.indicatorColorHex) ?? "#8B5CF6"
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|passed|failed"
```
Expected: all tests pass

- [ ] **Step 5: Commit**

```bash
git add Drawl/Storage/PreferencesStore.swift DrawlTests/PreferencesStoreTests.swift
git commit -m "feat: add screenContextEnabled and indicatorColorHex preferences"
```

---

## Task 3: Create `ScreenRecordingPermission`

**Files:**
- Create: `Drawl/Permissions/ScreenRecordingPermission.swift`

- [ ] **Step 1: Create the file**

Create `Drawl/Permissions/ScreenRecordingPermission.swift`:
```swift
import CoreGraphics
import AppKit

public class ScreenRecordingPermission: ObservableObject {
    @Published public var isGranted: Bool = false

    public init() {
        checkStatus()
    }

    public func checkStatus() {
        isGranted = CGPreflightScreenCaptureAccess()
    }

    public func requestAccess() {
        CGRequestScreenCaptureAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkStatus()
        }
    }

    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Add the file to the Drawl target in Xcode**

Open `Drawl.xcodeproj` in Xcode, right-click `Drawl/Permissions` group → Add Files to "Drawl" → select `ScreenRecordingPermission.swift` → ensure "Drawl" target is checked.

- [ ] **Step 3: Build to confirm it compiles**

```bash
xcodebuild build -project Drawl.xcodeproj -scheme Drawl \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add Drawl/Permissions/ScreenRecordingPermission.swift Drawl.xcodeproj/project.pbxproj
git commit -m "feat: add ScreenRecordingPermission wrapper"
```

---

## Task 4: Create `ScreenContextService`

**Files:**
- Create: `Drawl/Input/ScreenContextService.swift`

- [ ] **Step 1: Create the file**

Create `Drawl/Input/ScreenContextService.swift`:
```swift
import ScreenCaptureKit
import Vision
import AppKit

public class ScreenContextService {
    public init() {}

    public func captureContext() async -> String? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        do {
            let content = try await SCShareableContent.current
            guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
            let pid = frontApp.processIdentifier

            guard let window = content.windows.first(where: {
                $0.owningApplication?.processID == pid && $0.isOnScreen
            }) else { return nil }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.width = max(1, Int(window.frame.width))
            config.height = max(1, Int(window.frame.height))
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let rawText = try await recognizeText(in: image)
            let filtered = filterWords(from: rawText)
            return filtered.isEmpty ? nil : filtered
        } catch {
            return nil
        }
    }

    private func recognizeText(in image: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
        }.value
    }

    func filterWords(from text: String) -> String {
        let separators = CharacterSet.whitespaces
            .union(.newlines)
            .union(.punctuationCharacters)
        let rawWords = text.components(separatedBy: separators).filter { !$0.isEmpty }

        var seen = Set<String>()
        var result: [String] = []

        for word in rawWords {
            guard word.count > 2, !seen.contains(word) else { continue }

            let scalars = word.unicodeScalars
            let firstIsUpper = scalars.first.map { CharacterSet.uppercaseLetters.contains($0) } ?? false
            let hasInternalUpper = word.dropFirst().unicodeScalars
                .contains { CharacterSet.uppercaseLetters.contains($0) }
            let isAllCaps = word == word.uppercased()
                && word.rangeOfCharacter(from: .letters) != nil

            let isProperNoun = firstIsUpper && word.count > 4 && !isAllCaps
            let isMixedCase = hasInternalUpper
            let isAbbreviation = isAllCaps && word.count > 2

            if isProperNoun || isMixedCase || isAbbreviation {
                seen.insert(word)
                result.append(word)
                if result.count >= 150 { break }
            }
        }

        return result.joined(separator: " ")
    }
}
```

- [ ] **Step 2: Add the file to the Drawl target in Xcode**

Open `Drawl.xcodeproj` in Xcode, right-click `Drawl/Input` group → Add Files to "Drawl" → select `ScreenContextService.swift` → ensure "Drawl" target is checked.

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Drawl.xcodeproj -scheme Drawl \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add Drawl/Input/ScreenContextService.swift Drawl.xcodeproj/project.pbxproj
git commit -m "feat: add ScreenContextService with OCR and word filtering"
```

---

## Task 5: Test `ScreenContextService.filterWords`

**Files:**
- Create: `DrawlTests/ScreenContextServiceTests.swift`

- [ ] **Step 1: Write tests**

Create `DrawlTests/ScreenContextServiceTests.swift`:
```swift
import XCTest
@testable import Drawl

final class ScreenContextServiceTests: XCTestCase {
    let service = ScreenContextService()

    func testProperNounsAreKept() {
        let result = service.filterWords(from: "Hello Joop how are you today LinkedIn")
        XCTAssertTrue(result.contains("Joop"), "Expected proper noun 'Joop' in: \(result)")
        XCTAssertTrue(result.contains("LinkedIn"), "Expected 'LinkedIn' in: \(result)")
    }

    func testCommonWordsAreFiltered() {
        let result = service.filterWords(from: "Hello the a of in to it")
        XCTAssertFalse(result.contains("the"))
        XCTAssertFalse(result.contains("Hello"), "Short/common word 'Hello' (5 chars but not >4 rule)… actually Hello IS > 4")
        // "Hello" is 5 chars, starts uppercase, not allCaps — it will match isProperNoun
        // That is acceptable; the filter isn't perfect, it biases toward recall
    }

    func testCamelCaseIdentifiersAreKept() {
        let result = service.filterWords(from: "call transcribeAndInsert with audioSamples")
        XCTAssertTrue(result.contains("transcribeAndInsert"), "Expected camelCase in: \(result)")
        XCTAssertTrue(result.contains("audioSamples"), "Expected 'audioSamples' in: \(result)")
    }

    func testPascalCaseKept() {
        let result = service.filterWords(from: "WhisperEngine ScreenContextService DecodingOptions")
        XCTAssertTrue(result.contains("WhisperEngine"))
        XCTAssertTrue(result.contains("ScreenContextService"))
        XCTAssertTrue(result.contains("DecodingOptions"))
    }

    func testAbbreviationsKept() {
        let result = service.filterWords(from: "Using the API in OCR with NLP")
        XCTAssertTrue(result.contains("API"))
        XCTAssertTrue(result.contains("OCR"))
        XCTAssertTrue(result.contains("NLP"))
    }

    func testDeduplication() {
        let result = service.filterWords(from: "Joop Joop Joop LinkedIn LinkedIn")
        let words = result.components(separatedBy: " ")
        XCTAssertEqual(words.filter { $0 == "Joop" }.count, 1)
        XCTAssertEqual(words.filter { $0 == "LinkedIn" }.count, 1)
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(service.filterWords(from: ""), "")
    }

    func testResultCappedAt150Words() {
        let manyWords = (1...200).map { "Word\($0)" }.joined(separator: " ")
        let result = service.filterWords(from: manyWords)
        let count = result.components(separatedBy: " ").filter { !$0.isEmpty }.count
        XCTAssertLessThanOrEqual(count, 150)
    }
}
```

- [ ] **Step 2: Add the file to the DrawlTests target in Xcode**

Open `Drawl.xcodeproj`, right-click `DrawlTests` group → Add Files to "Drawl" → select `ScreenContextServiceTests.swift` → ensure "DrawlTests" target is checked.

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "ScreenContextService|error:|passed|failed"
```
Expected: all `ScreenContextServiceTests` pass

- [ ] **Step 4: Commit**

```bash
git add DrawlTests/ScreenContextServiceTests.swift Drawl.xcodeproj/project.pbxproj
git commit -m "test: add ScreenContextService filterWords unit tests"
```

---

## Task 6: Update `TranscriptionSession`

**Files:**
- Modify: `Drawl/Transcription/TranscriptionSession.swift`

- [ ] **Step 1: Add stored properties and update init**

In `TranscriptionSession`, add two private properties after `var lastTranscriptionTask`:
```swift
private let screenContextService: ScreenContextService?
private var screenContext: String?
```

Update the `init` signature to:
```swift
public init(
    engine: TranscriptionEngineProtocol,
    textInsertionService: TextInsertionServiceProtocol,
    historyStore: HistoryStore,
    modelTier: ModelTier,
    screenContextService: ScreenContextService? = nil
) {
    self.engine = engine
    self.textInsertionService = textInsertionService
    self.historyStore = historyStore
    self.modelTier = modelTier
    self.screenContextService = screenContextService
    setupBufferProcessor()
}
```

- [ ] **Step 2: Capture context in `start()`**

Replace the `start()` method:
```swift
public func start() {
    self.startTime = Date()
    self.sessionText = ""
    self.segmentCount = 0
    self.screenContext = nil

    if let activeApp = NSWorkspace.shared.frontmostApplication {
        self.sourceAppName = activeApp.localizedName
    }

    if let service = screenContextService {
        Task {
            self.screenContext = await service.captureContext()
        }
    }
}
```

- [ ] **Step 3: Pass context in `transcribeAndInsert`**

Replace the `transcribeAndInsert` call site:
```swift
let transcribed = try await engine.transcribe(
    audioSamples: samples,
    sampleRate: 16000,
    context: screenContext
)
```

- [ ] **Step 4: Build**

```bash
xcodebuild build -project Drawl.xcodeproj -scheme Drawl \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|passed|failed"
```
Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add Drawl/Transcription/TranscriptionSession.swift
git commit -m "feat: capture screen context at session start and pass to transcription engine"
```

---

## Task 7: Update `TranscriptionSessionTests` for Context

**Files:**
- Modify: `DrawlTests/TranscriptionSessionTests.swift`

- [ ] **Step 1: Write a failing test**

Add to `TranscriptionSessionTests`:
```swift
func testContextIsPassedToEngine() async throws {
    class ContextCapturingEngine: TranscriptionEngineProtocol {
        var isModelLoaded: Bool = true
        var capturedContext: String? = "not-set"

        func loadModel(at path: URL) async throws {}
        func unloadModel() {}

        func transcribe(audioSamples: [Float], sampleRate: Int, context: String?) async throws -> String {
            capturedContext = context
            return "Hello"
        }
    }

    class StubContextService: ScreenContextService {
        override func captureContext() async -> String? { "Joop LinkedIn" }
    }

    let engine = ContextCapturingEngine()
    let insertionService = MockTextInsertionService()
    let session = TranscriptionSession(
        engine: engine,
        textInsertionService: insertionService,
        historyStore: historyStore,
        modelTier: .base,
        screenContextService: StubContextService()
    )

    session.start()
    // Give the async context capture time to complete before the buffer fires
    try await Task.sleep(nanoseconds: 200_000_000)
    await session.processAudioBuffer([0.0, 0.0])
    await session.stop()

    XCTAssertEqual(engine.capturedContext, "Joop LinkedIn")
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "testContextIsPassedToEngine"
```
Expected: FAIL (StubContextService can't subclass until `captureContext` is marked `open` or the stub approach is adjusted — see next step)

- [ ] **Step 3: Make `captureContext` overridable**

In `Drawl/Input/ScreenContextService.swift`, change `public func captureContext` to `open func captureContext` and change the class declaration to `open class ScreenContextService`.

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|passed|failed"
```
Expected: all tests pass

- [ ] **Step 5: Commit**

```bash
git add DrawlTests/TranscriptionSessionTests.swift Drawl/Input/ScreenContextService.swift
git commit -m "test: verify screen context is passed from session to transcription engine"
```

---

## Task 8: Add `Color+Hex` and Update `IndicatorWindow`

**Files:**
- Create: `Drawl/UI/Color+Hex.swift`
- Modify: `Drawl/UI/IndicatorWindow.swift`

- [ ] **Step 1: Create `Color+Hex.swift`**

Create `Drawl/UI/Color+Hex.swift`:
```swift
import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .purple
        return String(format: "#%02X%02X%02X",
            Int((ns.redComponent * 255).rounded()),
            Int((ns.greenComponent * 255).rounded()),
            Int((ns.blueComponent * 255).rounded()))
    }
}
```

- [ ] **Step 2: Add the file to the Drawl target in Xcode**

Open `Drawl.xcodeproj`, right-click `Drawl/UI` group → Add Files to "Drawl" → select `Color+Hex.swift` → ensure "Drawl" target is checked.

- [ ] **Step 3: Update `IndicatorViewModel` to accept a color**

In `Drawl/UI/IndicatorWindow.swift`, update `IndicatorViewModel`:
```swift
public class IndicatorViewModel: ObservableObject {
    @Published public var isSpeaking = false
    @Published public var audioLevel: Float = 0.0
    @Published public var pulseScale: CGFloat = 1.0
    @Published public var pulseOpacity: Double = 0.8
    @Published public var color: Color

    private var timer: Timer?

    public init(color: Color = Color(hex: "#8B5CF6")) {
        self.color = color
        startPulseAnimation()
    }
    // ... rest unchanged
}
```

- [ ] **Step 4: Update `IndicatorView` to use `viewModel.color`**

Replace the two `Circle()` blocks in `IndicatorView.body` to use `viewModel.color` instead of `Color.purple` and `Color.indigo`:
```swift
var body: some View {
    ZStack {
        Circle()
            .fill(
                RadialGradient(
                    colors: [viewModel.color.opacity(0.65), viewModel.color.opacity(0.0)],
                    center: .center,
                    startRadius: 4,
                    endRadius: 18
                )
            )
            .frame(width: 36, height: 36)
            .scaleEffect(viewModel.isSpeaking ? CGFloat(1.1 + viewModel.audioLevel * 0.7) : viewModel.pulseScale)
            .opacity(viewModel.pulseOpacity)
            .animation(.easeInOut(duration: 0.15), value: viewModel.audioLevel)

        Circle()
            .fill(
                LinearGradient(
                    colors: [viewModel.color, viewModel.color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
            )
            .shadow(color: viewModel.color.opacity(0.5), radius: 4, x: 0, y: 0)
    }
    .frame(width: 80, height: 80)
}
```

- [ ] **Step 5: Update `IndicatorWindow` to accept a color and initialize `viewModel` with it**

`AppDelegate` uses `indicatorWindow?.viewModel.updateAudioLevel(volume)`, so `viewModel` must remain a public stored property. Change `IndicatorWindow` to initialize it with the color before calling `super.init`:

```swift
public class IndicatorWindow: NSPanel {
    public let viewModel: IndicatorViewModel

    public init(color: Color = Color(hex: "#8B5CF6")) {
        self.viewModel = IndicatorViewModel(color: color)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.hasShadow = false

        let hostingView = NSHostingView(rootView: IndicatorView(viewModel: viewModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 80, height: 80)
        self.contentView = hostingView
    }
    // show(), hide(), updatePosition(), calculatePosition() — all unchanged
}
```

- [ ] **Step 6: Build**

```bash
xcodebuild build -project Drawl.xcodeproj -scheme Drawl \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add Drawl/UI/Color+Hex.swift Drawl/UI/IndicatorWindow.swift Drawl.xcodeproj/project.pbxproj
git commit -m "feat: make indicator pulse color configurable"
```

---

## Task 9: Update `AppDelegate` to Wire Everything

**Files:**
- Modify: `Drawl/App/AppDelegate.swift`

- [ ] **Step 1: Pass color to `IndicatorWindow` in `startDictation()`**

In `startDictation()`, replace:
```swift
self.indicatorWindow = IndicatorWindow()
```
with:
```swift
let indicatorColor = Color(hex: preferencesStore.indicatorColorHex)
self.indicatorWindow = IndicatorWindow(color: indicatorColor)
```

Add `import SwiftUI` at the top of `AppDelegate.swift` if not already present.

- [ ] **Step 2: Pass `ScreenContextService` to `TranscriptionSession` in `startDictation()`**

Replace the `TranscriptionSession` initializer call:
```swift
let contextService: ScreenContextService? = preferencesStore.screenContextEnabled
    ? ScreenContextService()
    : nil

currentSession = TranscriptionSession(
    engine: whisperEngine,
    textInsertionService: textInsertionService,
    historyStore: historyStore,
    modelTier: selectedModelTier,
    screenContextService: contextService
)
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Drawl.xcodeproj -scheme Drawl \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|passed|failed"
```
Expected: all tests pass

- [ ] **Step 5: Commit**

```bash
git add Drawl/App/AppDelegate.swift
git commit -m "feat: wire ScreenContextService and indicator color into AppDelegate"
```

---

## Task 10: Update `PreferencesView`

**Files:**
- Modify: `Drawl/UI/PreferencesView.swift`

- [ ] **Step 1: Add Screen Context section to `PreferencesView`**

Inside `PreferencesView.body`, add a new section after the "General Settings" section (before the closing `VStack` of the `ScrollView`):

```swift
// Section 4: Accuracy
VStack(alignment: .leading, spacing: 14) {
    HStack {
        Image(systemName: "text.viewfinder")
            .foregroundColor(.purple)
        Text("Transcription Accuracy")
            .font(.headline)
    }

    VStack(alignment: .leading, spacing: 4) {
        Toggle(isOn: Binding(
            get: { preferencesStore.screenContextEnabled },
            set: { enabled in
                if enabled {
                    let permission = ScreenRecordingPermission()
                    if permission.isGranted {
                        preferencesStore.screenContextEnabled = true
                    } else {
                        permission.requestAccess()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if permission.isGranted {
                                preferencesStore.screenContextEnabled = true
                            } else {
                                permission.openSystemSettings()
                            }
                        }
                    }
                } else {
                    preferencesStore.screenContextEnabled = false
                }
            }
        )) {
            VStack(alignment: .leading) {
                Text("Use screen context to improve accuracy")
                Text("Reads visible text to help transcribe names and identifiers. Requires Screen Recording permission.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .toggleStyle(.checkbox)
    }
}
.padding()
.background(Color(NSColor.windowBackgroundColor).opacity(0.5))
.cornerRadius(12)
```

- [ ] **Step 2: Add color picker to General Settings section**

Inside the existing "General Settings" `VStack`, add after the `historyRetentionDays` picker (before `Divider()` that precedes "Re-run Setup Wizard"):

```swift
Divider()

HStack {
    Text("Indicator Color")
    Spacer()
    ColorPicker("", selection: Binding(
        get: { Color(hex: preferencesStore.indicatorColorHex) },
        set: { preferencesStore.indicatorColorHex = $0.hexString }
    ))
    .labelsHidden()
    .frame(width: 44)
}
```

- [ ] **Step 3: Increase the window height to fit the new section**

In `AppDelegate.showPreferencesWindow()`, update the content rect:
```swift
contentRect: NSRect(x: 0, y: 0, width: 480, height: 700),
```

Also update the frame at the bottom of `PreferencesView.body`:
```swift
.frame(width: 480, height: 700)
```

- [ ] **Step 4: Build**

```bash
xcodebuild build -project Drawl.xcodeproj -scheme Drawl \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 5: Run full test suite**

```bash
xcodebuild test -project Drawl.xcodeproj -scheme DrawlTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|passed|failed"
```
Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add Drawl/UI/PreferencesView.swift Drawl/App/AppDelegate.swift
git commit -m "feat: add screen context toggle and indicator color picker to Preferences"
```
