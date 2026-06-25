import Foundation

public class ModelManager: ModelManagerProtocol {
    private let fileManager = FileManager.default
    
    private var modelsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Drawl").appendingPathComponent("Models")
    }
    
    public init() {
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
    
    public func availableModels() -> [SpeechModel] {
        return ModelTier.allCases.map { tier in
            let path = expectedPath(for: tier)
            let isDownloaded = fileManager.fileExists(atPath: path.path)
            return SpeechModel(tier: tier, localPath: isDownloaded ? path : nil, isActive: false)
        }
    }
    
    public func download(model: SpeechModel, progress: @escaping (Float) -> Void) async throws {
        let destinationURL = expectedPath(for: model.tier)
        
        let (tempURL, response) = try await URLSession.shared.download(from: model.downloadURL)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AppError.modelDownloadFailed("Server returned error status")
        }
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }
    
    public func delete(model: SpeechModel) throws {
        let path = expectedPath(for: model.tier)
        if fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
        }
    }
    
    public func localPath(for model: SpeechModel) -> URL? {
        let path = expectedPath(for: model.tier)
        return fileManager.fileExists(atPath: path.path) ? path : nil
    }
    
    private func expectedPath(for tier: ModelTier) -> URL {
        return modelsDirectory.appendingPathComponent(tier.fileName)
    }
}
