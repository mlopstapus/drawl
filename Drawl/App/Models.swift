import Foundation

public enum ModelTier: String, CaseIterable, Codable {
    case tiny
    case base
    case small
    
    public var id: String {
        return "ggml-\(self.rawValue)"
    }
    
    public var displayName: String {
        switch self {
        case .tiny: return "Tiny — Fastest"
        case .base: return "Base — Balanced"
        case .small: return "Small — Best"
        }
    }
    
    public var fileName: String {
        return "ggml-\(self.rawValue).bin"
    }
    
    public var fileSizeInBytes: Int64 {
        switch self {
        case .tiny: return 75_000_000
        case .base: return 142_000_000
        case .small: return 466_000_000
        }
    }
    
    public var downloadURL: URL {
        return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(self.rawValue).bin")!
    }
}

public struct SpeechModel: Identifiable, Codable, Equatable {
    public var id: String
    public var tier: ModelTier
    public var displayName: String
    public var fileName: String
    public var fileSize: Int64
    public var downloadURL: URL
    public var localPath: URL?
    public var isDownloaded: Bool {
        guard let path = localPath else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }
    public var isActive: Bool
    
    public init(tier: ModelTier, localPath: URL? = nil, isActive: Bool = false) {
        self.id = tier.id
        self.tier = tier
        self.displayName = tier.displayName
        self.fileName = tier.fileName
        self.fileSize = tier.fileSizeInBytes
        self.downloadURL = tier.downloadURL
        self.localPath = localPath
        self.isActive = isActive
    }
}

public enum IndicatorPosition: String, CaseIterable, Codable {
    case nearCursor
    case topRight
    case topLeft
    case bottomRight
    case bottomLeft
}

public enum AppError: Error, Equatable, LocalizedError {
    case microphoneDenied
    case accessibilityDenied
    case modelDownloadFailed(String)
    case modelLoadFailed(String)
    case transcriptionFailed(String)
    case hotkeyConflict
    
    public var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access was denied. Please enable it in System Settings."
        case .accessibilityDenied:
            return "Accessibility access is required to type transcribed text."
        case .modelDownloadFailed(let message):
            return "Failed to download model: \(message)"
        case .modelLoadFailed(let message):
            return "Failed to load model: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .hotkeyConflict:
            return "The selected hotkey is already in use by another application."
        }
    }
}

public enum AppState: Equatable {
    case idle
    case listening
    case processing
    case setupRequired
    case modelDownloading(progress: Float)
    case error(AppError)
    
    public static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.listening, .listening), (.processing, .processing), (.setupRequired, .setupRequired):
            return true
        case (.modelDownloading(let p1), .modelDownloading(let p2)):
            return p1 == p2
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}
