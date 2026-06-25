import AVFoundation
import Combine

public class MicrophonePermission: ObservableObject {
    @Published public var isGranted: Bool = false
    
    public init() {
        checkStatus()
    }
    
    public func checkStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        self.isGranted = (status == .authorized)
    }
    
    public func requestAccess(completion: @escaping (Bool) -> Void = { _ in }) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isGranted = granted
                completion(granted)
            }
        }
    }
}
