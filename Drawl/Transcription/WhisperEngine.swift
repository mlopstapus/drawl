import Foundation
import WhisperKit

public class WhisperEngine: TranscriptionEngineProtocol {
    private var whisperKit: WhisperKit?

    public var isModelLoaded: Bool { whisperKit != nil }

    public init() {}

    public func loadModel(at path: URL) async throws {
        do {
            whisperKit = try await WhisperKit(modelFolder: path.path, verbose: false)
        } catch {
            throw AppError.modelLoadFailed("Failed to initialize WhisperKit: \(error.localizedDescription)")
        }
    }

    public func transcribe(audioSamples: [Float], sampleRate: Int, context: String?) async throws -> String {
        guard let wk = whisperKit else {
            throw AppError.transcriptionFailed("Model is not loaded")
        }
        guard sampleRate == 16000 else {
            throw AppError.transcriptionFailed("Invalid sample rate: \(sampleRate). Whisper requires 16000Hz.")
        }
        var options = DecodingOptions()
        if let context = context, !context.isEmpty, let tokenizer = wk.tokenizer {
            let promptTokens = tokenizer.encode(text: " " + context.trimmingCharacters(in: .whitespaces))
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            if !promptTokens.isEmpty {
                options.promptTokens = promptTokens
            }
        }
        let results = try await wk.transcribe(audioArray: audioSamples, decodeOptions: options)
        return results.map { $0.text }.joined()
            .replacingOccurrences(of: "[BLANK_AUDIO]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func unloadModel() {
        whisperKit = nil
    }
}
