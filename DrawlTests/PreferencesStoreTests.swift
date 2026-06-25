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
        
        XCTAssertEqual(store.hotkeyKeyCode, 55)
        XCTAssertEqual(store.hotkeyModifiers, 1048576) // ⌘ (Command) modifier value
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
    
    func testPreferencesChangeReconfiguresHotkey() {
        let appDelegate = AppDelegate()
        
        let testSuiteName = "com.ben.drawl.test.preferences.delegate.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)
        
        // Re-inject a clean preferences store with test defaults
        let testStore = PreferencesStore(defaults: testDefaults!)
        appDelegate.preferencesStore = testStore
        // Set test values in testStore
        testStore.hotkeyKeyCode = 49 // Space
        testStore.hotkeyModifiers = 524288 // Option
        
        // Call applicationDidFinishLaunching to set up the Combine sink
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Overwrite the delegate's callback with our test callback
        var downCalled = false
        appDelegate.hotkeyManager.onHotkeyDown = {
            downCalled = true
        }
        
        // Let's set a new hotkey keyCode and modifier on appDelegate's preferencesStore
        appDelegate.preferencesStore.hotkeyKeyCode = 9 // 'V'
        appDelegate.preferencesStore.hotkeyModifiers = 1048576 // Cmd
        
        // Wait for objectWillChange dispatch to run
        let expectation = XCTestExpectation(description: "Preferences change processed")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Now try to simulate KeyDown for 'V' (keyCode 9) and Cmd (1048576)
        let handled = appDelegate.hotkeyManager.handleEvent(type: .keyDown, keyCode: 9, modifierFlags: 1048576)
        XCTAssertTrue(handled, "New hotkey should be handled by HotkeyManager")
        XCTAssertTrue(downCalled, "onHotkeyDown callback should have been called")
        
        testDefaults?.removePersistentDomain(forName: testSuiteName)
    }
}
