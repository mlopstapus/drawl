import Combine
import CoreGraphics
import AppKit

public class ScreenRecordingPermission: ObservableObject {
    @Published public var isGranted: Bool = false

    public init() {
        checkStatus()
    }

    public func checkStatus() {
        isGranted = CGPreflightScreenCaptureAccess()
    }

    public func requestAccess() {
        CGRequestScreenCaptureAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkStatus()
        }
    }

    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
