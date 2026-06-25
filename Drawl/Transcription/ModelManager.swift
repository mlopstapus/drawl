import Foundation
import WhisperKit

public class ModelManager: ModelManagerProtocol {
    private let fileManager = FileManager.default
    private let baseDirectory: URL

    public init(baseDirectory: URL? = nil) {
        if let base = baseDirectory {
            self.baseDirectory = base
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseDirectory = appSupport.appendingPathComponent("Drawl").appendingPathComponent("Models")
        }
        try? fileManager.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }

    public func availableModels() -> [SpeechModel] {
        return ModelTier.allCases.map { tier in
            let path = localPath(for: SpeechModel(tier: tier))
            return SpeechModel(tier: tier, localPath: path, isActive: false)
        }
    }

    public func download(model: SpeechModel, progress: @escaping (Float) -> Void) async throws {
        let modelFolder = try await WhisperKit.download(
            variant: model.tier.rawValue,
            progressCallback: { p in progress(Float(p.fractionCompleted)) }
        )
        // Record the resolved path so localPath() can find it without tracking hub hashes
        let record = pathRecordURL(for: model.tier)
        try modelFolder.path.write(to: record, atomically: true, encoding: .utf8)
    }

    public func delete(model: SpeechModel) throws {
        if let path = localPath(for: model) {
            try? fileManager.removeItem(at: path)
        }
        try? fileManager.removeItem(at: pathRecordURL(for: model.tier))
    }

    public func localPath(for model: SpeechModel) -> URL? {
        let record = pathRecordURL(for: model.tier)
        guard let savedPath = try? String(contentsOf: record, encoding: .utf8),
              !savedPath.isEmpty else { return nil }
        let url = URL(fileURLWithPath: savedPath, isDirectory: false)
        guard fileManager.fileExists(atPath: savedPath) else {
            try? fileManager.removeItem(at: record)
            return nil
        }
        return url
    }

    private func pathRecordURL(for tier: ModelTier) -> URL {
        return baseDirectory.appendingPathComponent("\(tier.rawValue).modelpath")
    }
}
