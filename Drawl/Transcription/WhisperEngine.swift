import Foundation
import whisper

public class WhisperEngine: TranscriptionEngineProtocol {
    private var context: OpaquePointer?
    
    public var isModelLoaded: Bool {
        return context != nil
    }
    
    public init() {}
    
    deinit {
        unloadModel()
    }
    
    public func loadModel(at path: URL) async throws {
        unloadModel()
        
        let pathString = path.path
        
        let params = whisper_context_default_params()
        guard let ctx = whisper_init_from_file_with_params(pathString, params) else {
            throw AppError.modelLoadFailed("Failed to initialize whisper context from file: \(path.lastPathComponent)")
        }
        
        self.context = ctx
    }
    
    public func transcribe(audioSamples: [Float], sampleRate: Int) async throws -> String {
        guard let ctx = context else {
            throw AppError.transcriptionFailed("Model is not loaded")
        }
        
        guard sampleRate == 16000 else {
            throw AppError.transcriptionFailed("Invalid sample rate: \(sampleRate). Whisper requires 16000Hz mono audio.")
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
            throw AppError.transcriptionFailed("whisper_full execution failed")
        }
        
        let numSegments = whisper_full_n_segments(ctx)
        var resultText = ""
        for i in 0..<numSegments {
            if let segmentText = whisper_full_get_segment_text(ctx, i) {
                resultText += String(cString: segmentText)
            }
        }
        
        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func unloadModel() {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
    }
}
