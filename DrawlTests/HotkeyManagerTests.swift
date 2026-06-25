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
        // In unit tests running in a sandboxed/non-privileged test environment,
        // the actual OS-level registration might fail or be skipped, but the
        // manager's internal logic should still support mock event routing.
        do {
            try manager.register(keyCode: 49, modifiers: 524288)
        } catch {
            // Gracefully ignore registration errors in test environments where AX is missing
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
}
