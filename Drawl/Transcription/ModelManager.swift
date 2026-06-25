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
        
        let delegate = DownloadDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        
        let tempURL: URL = try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: model.downloadURL)
            delegate.continuation = continuation
            task.resume()
        }
        
        session.finishTasksAndInvalidate()
        
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

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let progress: (Float) -> Void
    var continuation: CheckedContinuation<URL, Error>?
    
    init(progress: @escaping (Float) -> Void) {
        self.progress = progress
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let pct = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        progress(pct)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        continuation?.resume(returning: location)
        continuation = nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
