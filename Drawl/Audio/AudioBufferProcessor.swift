import Foundation

public class AudioBufferProcessor {
    public var onSegmentReady: (([Float]) -> Void)?
    
    private var sampleBuffer: [Float] = []
    private let sampleRate = 16000
    private let maxSegmentDuration: TimeInterval = 5.0
    private let silenceThreshold: Float = 0.015
    private let silenceDurationThreshold: TimeInterval = 0.5 // 500ms
    
    private var consecutiveSilenceDuration: TimeInterval = 0.0
    
    public init() {}
    
    public func process(samples: [Float]) {
        guard !samples.isEmpty else { return }
        
        sampleBuffer.append(contentsOf: samples)
        
        let rms = calculateRMS(samples)
        let chunkDuration = Double(samples.count) / Double(sampleRate)
        
        if rms < silenceThreshold {
            consecutiveSilenceDuration += chunkDuration
        } else {
            consecutiveSilenceDuration = 0.0
        }
        
        let accumulatedDuration = Double(sampleBuffer.count) / Double(sampleRate)
        
        let reachedMaxDuration = accumulatedDuration >= maxSegmentDuration
        let reachedSilence = consecutiveSilenceDuration >= silenceDurationThreshold && accumulatedDuration >= 1.0
        
        if reachedMaxDuration || reachedSilence {
            triggerSegment()
        }
    }
    
    public func flush() {
        if !sampleBuffer.isEmpty {
            triggerSegment()
        }
    }
    
    private func triggerSegment() {
        let segment = sampleBuffer
        sampleBuffer.removeAll(keepingCapacity: true)
        consecutiveSilenceDuration = 0.0
        if !segment.isEmpty {
            onSegmentReady?(segment)
        }
    }
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        let sumOfSquares = samples.reduce(0.0) { $0 + ($1 * $1) }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}
