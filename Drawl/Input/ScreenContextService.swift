import ScreenCaptureKit
import Vision
import AppKit

open class ScreenContextService {
    public init() {}

    open func captureContext() async -> String? {
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
            NSLog("[ScreenContext] raw OCR (%d chars): %{public}@", rawText.count, String(rawText.prefix(300)))
            let filtered = filterWords(from: rawText)
            NSLog("[ScreenContext] filtered words: %{public}@", filtered.isEmpty ? "(none)" : filtered)
            return filtered.isEmpty ? nil : filtered
        } catch {
            NSLog("[ScreenContext] capture failed: %{public}@", error.localizedDescription)
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

    public func filterWords(from text: String) -> String {
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

            let isProperNoun = firstIsUpper && word.count >= 4 && !isAllCaps
            let isMixedCase = hasInternalUpper && !isAllCaps
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
