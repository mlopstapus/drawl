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
        let manager = ModelManager()
        let models = manager.availableModels()
        let firstModel = models[0]
        
        XCTAssertNil(manager.localPath(for: firstModel))
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dummyPath = appSupport.appendingPathComponent("Drawl").appendingPathComponent("Models").appendingPathComponent(firstModel.tier.fileName)
        
        try Data("dummy".utf8).write(to: dummyPath)
        
        let resolvedPath = manager.localPath(for: firstModel)
        XCTAssertNotNil(resolvedPath)
        XCTAssertEqual(resolvedPath, dummyPath)
        
        try manager.delete(model: firstModel)
        XCTAssertNil(manager.localPath(for: firstModel))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dummyPath.path))
    }
}
