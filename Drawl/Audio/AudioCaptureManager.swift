import Foundation
import AVFoundation

public class AudioCaptureManager {
    private let audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    public var onAudioBuffer: (([Float]) -> Void)?
    
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    
    public init() {}
    
    public func start() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AppError.transcriptionFailed("Failed to create audio format converter")
        }
        self.audioConverter = converter
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        try audioEngine.start()
    }
    
    public func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioConverter = nil
    }
    
    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter ?? AVAudioConverter(from: buffer.format, to: targetFormat) else { return }
        
        let sampleRateRatio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * sampleRateRatio) + 16
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        if status == .error || error != nil {
            print("Audio conversion error: \(error?.localizedDescription ?? "unknown")")
            return
        }
        
        guard let floatData = outputBuffer.floatChannelData?[0] else { return }
        let frameCount = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatData, count: frameCount))
        
        if !samples.isEmpty {
            onAudioBuffer?(samples)
        }
    }
}
