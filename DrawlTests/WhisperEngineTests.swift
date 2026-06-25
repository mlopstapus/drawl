import XCTest
@testable import Drawl

final class WhisperEngineTests: XCTestCase {
    func testModelLoadStateAndUnload() async throws {
        let engine = WhisperEngine()
        
        XCTAssertFalse(engine.isModelLoaded)
        
        let nonexistentURL = URL(fileURLWithPath: "/path/to/nonexistent/model-folder")
        do {
            try await engine.loadModel(at: nonexistentURL)
            XCTFail("Should have failed to load nonexistent model file")
        } catch {
            // Expected error
        }
        
        XCTAssertFalse(engine.isModelLoaded)
        
        do {
            _ = try await engine.transcribe(audioSamples: [0.0], sampleRate: 16000, context: nil)
            XCTFail("Should have failed to transcribe without model loaded")
        } catch {
            // Expected error
        }
        
        engine.unloadModel()
        XCTAssertFalse(engine.isModelLoaded)
    }
}
