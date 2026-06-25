import Foundation

public protocol TranscriptionEngineProtocol {
    func loadModel(at path: URL) async throws
    func transcribe(audioSamples: [Float], sampleRate: Int) async throws -> String
    func unloadModel()
    var isModelLoaded: Bool { get }
}

public protocol HotkeyManagerProtocol {
    var onHotkeyDown: (() -> Void)? { get set }
    var onHotkeyUp: (() -> Void)? { get set }
    func register(keyCode: UInt16, modifiers: UInt64) throws
    func unregister()
}

public protocol TextInsertionServiceProtocol {
    func insertText(_ text: String) async throws
    func canInsertIntoFocusedElement() -> Bool
}

public protocol ModelManagerProtocol {
    func availableModels() -> [SpeechModel]
    func download(model: SpeechModel, progress: @escaping (Float) -> Void) async throws
    func delete(model: SpeechModel) throws
    func localPath(for model: SpeechModel) -> URL?
}
