import Foundation
import ApplicationServices
import Combine
import AppKit

public class AccessibilityPermission: ObservableObject {
    @Published public var isGranted: Bool = false
    private var timer: Timer?
    
    public init() {
        checkStatus()
    }
    
    deinit {
        stopPolling()
    }
    
    public func checkStatus() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let status = AXIsProcessTrustedWithOptions(options)
        NSLog("[AccessibilityPermission] checkStatus: status = \(status)")
        if self.isGranted != status {
            DispatchQueue.main.async {
                self.isGranted = status
            }
        }
    }
    
    public func startPolling() {
        NSLog("[AccessibilityPermission] startPolling called")
        timer?.invalidate()
        checkStatus()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let oldStatus = self.isGranted
            
            // Check status directly
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
            let status = AXIsProcessTrustedWithOptions(options)
            
            NSLog("[AccessibilityPermission] Timer tick: oldStatus = \(oldStatus), newStatus = \(status)")
            
            if status != oldStatus {
                NSLog("[AccessibilityPermission] Status changed! Updating isGranted to \(status)")
                DispatchQueue.main.async {
                    self.isGranted = status
                }
            }
            
            if status && !oldStatus {
                NSLog("[AccessibilityPermission] Trusted status gained, stopping polling.")
                self.stopPolling()
            }
        }
        
        // Ensure the timer fires even when the app is in the background or tracking menus/windows
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    public func stopPolling() {
        NSLog("[AccessibilityPermission] stopPolling called")
        timer?.invalidate()
        timer = nil
    }
    
    public func openSystemSettings() {
        NSLog("[AccessibilityPermission] openSystemSettings called")
        // Prompt option set to true registers the app in the Accessibility database
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

