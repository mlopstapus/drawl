import XCTest
@testable import Drawl

final class HotkeyManagerTests: XCTestCase {
    func testHotkeyRegistrationAndCallback() {
        let manager = HotkeyManager()
        
        var downCalled = false
        var upCalled = false
        
        manager.onHotkeyDown = {
            downCalled = true
        }
        manager.onHotkeyUp = {
            upCalled = true
        }
        
        // Register Option+Space (49, 524288)
        do {
            try manager.register(keyCode: 49, modifiers: 524288)
        } catch {
            print("Skipping actual OS hotkey registration in test: \(error)")
        }
        
        // Simulate key-down event matching our hotkey
        let handledDown = manager.handleEvent(type: .keyDown, keyCode: 49, modifierFlags: 524288)
        XCTAssertTrue(handledDown)
        XCTAssertTrue(downCalled)
        
        // Simulate key-up event matching our hotkey
        let handledUp = manager.handleEvent(type: .keyUp, keyCode: 49, modifierFlags: 524288)
        XCTAssertTrue(handledUp)
        XCTAssertTrue(upCalled)
        
        // Simulate an unrelated key event and verify it's not handled
        let handledOther = manager.handleEvent(type: .keyDown, keyCode: 5, modifierFlags: 0)
        XCTAssertFalse(handledOther)
        
        manager.unregister()
    }
    
    func testModifierOnlyHotkey() {
        let manager = HotkeyManager()
        
        var downCalled = false
        var upCalled = false
        
        manager.onHotkeyDown = {
            downCalled = true
        }
        manager.onHotkeyUp = {
            upCalled = true
        }
        
        // Register Left Command (55, 1048576)
        do {
            try manager.register(keyCode: 55, modifiers: 1048576)
        } catch {
            print("Skipping actual OS hotkey registration in test: \(error)")
        }
        
        // Pressing Left Command generates flagsChanged event with command flag
        let handledDown = manager.handleEvent(type: .flagsChanged, keyCode: 55, modifierFlags: 1048576)
        XCTAssertFalse(handledDown) // Modifier events are never consumed
        XCTAssertTrue(downCalled)
        
        // Releasing Left Command generates flagsChanged event without command flag
        let handledUp = manager.handleEvent(type: .flagsChanged, keyCode: 55, modifierFlags: 0)
        XCTAssertFalse(handledUp)
        XCTAssertTrue(upCalled)
        
        manager.unregister()
    }
    
    func testModifierOnlyHotkeyCancellation() {
        let manager = HotkeyManager()
        
        var downCalled = false
        var cancelCalled = false
        
        manager.onHotkeyDown = {
            downCalled = true
        }
        manager.onHotkeyCancel = {
            cancelCalled = true
        }
        
        // Register Left Command (55, 1048576)
        do {
            try manager.register(keyCode: 55, modifiers: 1048576)
        } catch {
            print("Skipping actual OS hotkey registration in test: \(error)")
        }
        
        // Press Left Command (starts dictation)
        _ = manager.handleEvent(type: .flagsChanged, keyCode: 55, modifierFlags: 1048576)
        XCTAssertTrue(downCalled)
        XCTAssertFalse(cancelCalled)
        
        // Press C key while holding Command (triggers system shortcut, cancels dictation)
        let handledKeyDown = manager.handleEvent(type: .keyDown, keyCode: 8, modifierFlags: 1048576)
        XCTAssertFalse(handledKeyDown) // KeyDown event is not consumed to allow system shortcut to function
        XCTAssertTrue(cancelCalled)
        
        manager.unregister()
    }
}
