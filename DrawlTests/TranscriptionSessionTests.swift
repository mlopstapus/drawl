import XCTest
import GRDB
@testable import Drawl

class MockTranscriptionEngine: TranscriptionEngineProtocol {
    var isModelLoaded: Bool = true
    var loadCount = 0
    var unloadCount = 0
    var transcribeCount = 0
    var mockResultText = "Hello"
    
    func loadModel(at path: URL) async throws {
        loadCount += 1
    }
    
    func transcribe(audioSamples: [Float], sampleRate: Int) async throws -> String {
        transcribeCount += 1
        return mockResultText
    }
    
    func unloadModel() {
        unloadCount += 1
    }
}

class MockTextInsertionService: TextInsertionServiceProtocol {
    var insertedText: [String] = []
    var canInsert = true
    
    func insertText(_ text: String) async throws {
        insertedText.append(text)
    }
    
    func canInsertIntoFocusedElement() -> Bool {
        return canInsert
    }
}

final class TranscriptionSessionTests: XCTestCase {
    var dbQueue: DatabaseQueue!
    var historyStore: HistoryStore!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        dbQueue = try DatabaseQueue()
        historyStore = try HistoryStore(databaseWriter: dbQueue)
    }
    
    func testSessionLifecycleAndHistoryInsertion() async throws {
        let engine = MockTranscriptionEngine()
        let insertionService = MockTextInsertionService()
        
        let session = TranscriptionSession(
            engine: engine,
            textInsertionService: insertionService,
            historyStore: historyStore,
            modelTier: .base
        )
        
        session.start()
        
        // Process a block of samples (simulates audio processing loop)
        await session.processAudioBuffer([0.0, 0.0])
        
        await session.stop()
        
        XCTAssertEqual(engine.transcribeCount, 1)
        XCTAssertEqual(insertionService.insertedText.count, 1)
        XCTAssertEqual(insertionService.insertedText.first, "Hello ")
        
        XCTAssertEqual(try historyStore.count(), 1)
        let entries = try historyStore.fetchAll()
        XCTAssertEqual(entries.first?.text, "Hello")
        XCTAssertEqual(entries.first?.modelTier, "base")
    }
}
