import XCTest
import AVFoundation
@testable import Drawl

final class AudioCaptureTests: XCTestCase {
    func testAudioFormatConversionAndAccumulation() {
        let manager = AudioCaptureManager()
        
        var bufferReceived = false
        var receivedSamplesCount = 0
        
        manager.onAudioBuffer = { samples in
            bufferReceived = true
            receivedSamplesCount += samples.count
        }
        
        let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let frameCount: AVAudioFrameCount = 44100 // 1 second of audio
        let mockBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount)!
        mockBuffer.frameLength = frameCount
        
        // Fill buffer with mock sine wave (440Hz tone)
        if let channels = mockBuffer.floatChannelData {
            for frame in 0..<Int(frameCount) {
                let sampleValue = Float(sin(2.0 * Float.pi * 440.0 * Float(frame) / 44100.0))
                channels[0][frame] = sampleValue
                channels[1][frame] = sampleValue
            }
        }
        
        // Feed the mock buffer into the manager's processing pipe
        manager.processAudioBuffer(mockBuffer)
        
        // Fed 1.0s of 44.1kHz audio; converted output should be 1.0s of 16kHz audio (~16000 samples)
        XCTAssertTrue(bufferReceived)
        XCTAssertEqual(receivedSamplesCount, 16000, accuracy: 100)
    }
}
