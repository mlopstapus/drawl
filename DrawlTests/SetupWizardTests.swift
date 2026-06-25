import XCTest
import AVFoundation
@testable import Drawl

final class SetupWizardTests: XCTestCase {
    func testSetupFlowIncompleteByDefault() {
        let appDelegate = AppDelegate()
        
        // Initial setup check
        appDelegate.checkSetupAndInitialize()
        
        // Setup should be required because permissions / models are missing in clean test environment
        XCTAssertFalse(appDelegate.preferencesStore.hasCompletedSetup)
        XCTAssertEqual(appDelegate.appState, .setupRequired)
    }
    
    func testMicrophonePermissionStatus() {
        let micPermission = MicrophonePermission()
        micPermission.checkStatus()
        let expected = (AVCaptureDevice.authorizationStatus(for: .audio) == .authorized)
        XCTAssertEqual(micPermission.isGranted, expected)
    }
    
    func testAccessibilityPermissionStatus() {
        let accessPermission = AccessibilityPermission()
        accessPermission.checkStatus()
        let expected = AXIsProcessTrusted()
        XCTAssertEqual(accessPermission.isGranted, expected)
    }
}
