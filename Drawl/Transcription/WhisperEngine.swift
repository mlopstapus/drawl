import Foundation
import whisper

public class WhisperEngine: TranscriptionEngineProtocol {
    private var context: OpaquePointer?
    private let queue = DispatchQueue(label: "com.ben.Drawl.WhisperEngine", qos: .userInitiated)
    
    public var isModelLoaded: Bool {
        return queue.sync {
            return context != nil
        }
    }
    
    public init() {}
    
    deinit {
        unloadModel()
    }
    
    public func loadModel(at path: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.unloadModelInternal()
                
                let pathString = path.path
                let params = whisper_context_default_params()
                guard let ctx = whisper_init_from_file_with_params(pathString, params) else {
                    continuation.resume(throwing: AppError.modelLoadFailed("Failed to initialize whisper context from file: \(path.lastPathComponent)"))
                    return
                }
                
                self.context = ctx
                continuation.resume()
            }
        }
    }
    
    public func transcribe(audioSamples: [Float], sampleRate: Int) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AppError.transcriptionFailed("WhisperEngine was deallocated"))
                    return
                }
                
                guard let ctx = self.context else {
                    continuation.resume(throwing: AppError.transcriptionFailed("Model is not loaded"))
                    return
                }
                
                guard sampleRate == 16000 else {
                    continuation.resume(throwing: AppError.transcriptionFailed("Invalid sample rate: \(sampleRate). Whisper requires 16000Hz mono audio."))
                    return
                }
                
                var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
                params.print_progress = false
                params.print_special = false
                params.print_realtime = false
                params.print_timestamps = false
                
                let languageCode = "en"
                var transcriptionError = false
                
                languageCode.withCString { cStr in
                    params.language = cStr
                    
                    let count = Int32(audioSamples.count)
                    audioSamples.withUnsafeBufferPointer { buffer in
                        let result = whisper_full(ctx, params, buffer.baseAddress, count)
                        if result != 0 {
                            transcriptionError = true
                        }
                    }
                }
                
                if transcriptionError {
                    continuation.resume(throwing: AppError.transcriptionFailed("whisper_full execution failed"))
                    return
                }
                
                let numSegments = whisper_full_n_segments(ctx)
                var resultText = ""
                for i in 0..<numSegments {
                    if let segmentText = whisper_full_get_segment_text(ctx, i) {
                        resultText += String(cString: segmentText)
                    }
                }
                
                continuation.resume(returning: resultText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
    
    public func unloadModel() {
        queue.sync {
            self.unloadModelInternal()
        }
    }
    
    private func unloadModelInternal() {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
    }
}
