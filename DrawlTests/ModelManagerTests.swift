import XCTest
@testable import Drawl

final class ModelManagerTests: XCTestCase {
    func testAvailableModels() {
        let manager = ModelManager()
        let models = manager.availableModels()
        XCTAssertEqual(models.count, 3)
        XCTAssertEqual(models[0].tier, .tiny)
        XCTAssertEqual(models[1].tier, .base)
        XCTAssertEqual(models[2].tier, .small)
    }

    func testLocalPathAndDeletion() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let manager = ModelManager(baseDirectory: tempDir)
        let firstModel = manager.availableModels()[0]

        // No model downloaded yet
        XCTAssertNil(manager.localPath(for: firstModel))

        // Simulate a WhisperKit download by writing a fake model folder and its path record
        let fakeModelFolder = tempDir.appendingPathComponent("fake-whisperkit-model")
        try FileManager.default.createDirectory(at: fakeModelFolder, withIntermediateDirectories: true)
        let record = tempDir.appendingPathComponent("\(firstModel.tier.rawValue).modelpath")
        try fakeModelFolder.path.write(to: record, atomically: true, encoding: .utf8)

        let resolvedPath = manager.localPath(for: firstModel)
        XCTAssertNotNil(resolvedPath)
        XCTAssertEqual(resolvedPath, fakeModelFolder)

        try manager.delete(model: firstModel)
        XCTAssertNil(manager.localPath(for: firstModel))
        XCTAssertFalse(FileManager.default.fileExists(atPath: record.path))
    }
}
