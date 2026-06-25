import XCTest
@testable import Drawl

final class PreferencesStoreTests: XCTestCase {
    var userDefaultsSuite: UserDefaults!
    var suiteName: String!
    
    override func setUp() {
        super.setUp()
        suiteName = "com.ben.drawl.test.preferences.\(UUID().uuidString)"
        userDefaultsSuite = UserDefaults(suiteName: suiteName)
    }
    
    override func tearDown() {
        userDefaultsSuite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }
    
    func testDefaultValues() {
        let store = PreferencesStore(defaults: userDefaultsSuite)
        
        XCTAssertEqual(store.hotkeyKeyCode, 49)
        XCTAssertEqual(store.hotkeyModifiers, 524288) // ⌥ (Option) modifier value
        XCTAssertEqual(store.selectedModelId, "ggml-base")
        XCTAssertEqual(store.language, "en")
        XCTAssertEqual(store.indicatorPosition, .nearCursor)
        XCTAssertFalse(store.launchAtLogin)
        XCTAssertFalse(store.hasCompletedSetup)
        XCTAssertEqual(store.historyRetentionDays, 30)
    }
    
    func testReadWriteHotkeySettings() {
        let store = PreferencesStore(defaults: userDefaultsSuite)
        
        store.hotkeyKeyCode = 9
        store.hotkeyModifiers = 1048576
        
        XCTAssertEqual(store.hotkeyKeyCode, 9)
        XCTAssertEqual(store.hotkeyModifiers, 1048576)
        
        let anotherStore = PreferencesStore(defaults: userDefaultsSuite)
        XCTAssertEqual(anotherStore.hotkeyKeyCode, 9)
        XCTAssertEqual(anotherStore.hotkeyModifiers, 1048576)
    }
    
    func testReadWriteModelAndOtherSettings() {
        let store = PreferencesStore(defaults: userDefaultsSuite)
        
        store.selectedModelId = "ggml-tiny"
        store.language = "es"
        store.indicatorPosition = .topRight
        store.launchAtLogin = true
        store.hasCompletedSetup = true
        store.historyRetentionDays = 15
        
        XCTAssertEqual(store.selectedModelId, "ggml-tiny")
        XCTAssertEqual(store.language, "es")
        XCTAssertEqual(store.indicatorPosition, .topRight)
        XCTAssertTrue(store.launchAtLogin)
        XCTAssertTrue(store.hasCompletedSetup)
        XCTAssertEqual(store.historyRetentionDays, 15)
        
        let anotherStore = PreferencesStore(defaults: userDefaultsSuite)
        XCTAssertEqual(anotherStore.selectedModelId, "ggml-tiny")
        XCTAssertEqual(anotherStore.language, "es")
        XCTAssertEqual(anotherStore.indicatorPosition, .topRight)
        XCTAssertTrue(anotherStore.launchAtLogin)
        XCTAssertTrue(anotherStore.hasCompletedSetup)
        XCTAssertEqual(anotherStore.historyRetentionDays, 15)
    }
}
