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
        if self.isGranted != status {
            DispatchQueue.main.async {
                self.isGranted = status
            }
        }
    }
    
    public func startPolling() {
        timer?.invalidate()
        checkStatus()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let oldStatus = self.isGranted
            
            // Check status directly
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
            let status = AXIsProcessTrustedWithOptions(options)
            
            if status != oldStatus {
                DispatchQueue.main.async {
                    self.isGranted = status
                }
            }
            
            if status && !oldStatus {
                self.stopPolling()
            }
        }
    }
    
    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    public func openSystemSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
