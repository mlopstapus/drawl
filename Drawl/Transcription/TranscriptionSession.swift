import Foundation
import AppKit

public class TranscriptionSession {
    private let engine: TranscriptionEngineProtocol
    private let textInsertionService: TextInsertionServiceProtocol
    private let historyStore: HistoryStore
    private let modelTier: ModelTier
    
    private let bufferProcessor = AudioBufferProcessor()
    private var startTime: Date?
    private var sessionText: String = ""
    private var segmentCount = 0
    private var sourceAppName: String?
    private var lastTranscriptionTask: Task<Void, Never>?
    private let screenContextService: ScreenContextService?
    private var screenContextTask: Task<String?, Never>?

    public init(
        engine: TranscriptionEngineProtocol,
        textInsertionService: TextInsertionServiceProtocol,
        historyStore: HistoryStore,
        modelTier: ModelTier,
        screenContextService: ScreenContextService? = nil
    ) {
        self.engine = engine
        self.textInsertionService = textInsertionService
        self.historyStore = historyStore
        self.modelTier = modelTier
        self.screenContextService = screenContextService
        setupBufferProcessor()
    }
    
    private func setupBufferProcessor() {
        bufferProcessor.onSegmentReady = { [weak self] samples in
            guard let self = self else { return }
            self.lastTranscriptionTask = Task {
                await self.transcribeAndInsert(samples)
            }
        }
    }
    
    public func start() {
        self.startTime = Date()
        self.sessionText = ""
        self.segmentCount = 0
        self.screenContextTask?.cancel()
        self.screenContextTask = nil

        if let activeApp = NSWorkspace.shared.frontmostApplication {
            self.sourceAppName = activeApp.localizedName
        }

        if let service = screenContextService {
            self.screenContextTask = Task {
                await service.captureContext()
            }
        }
    }
    
    public func stop() async {
        bufferProcessor.flush()
        await lastTranscriptionTask?.value

        guard let start = startTime, !sessionText.isEmpty else { return }
        
        let end = Date()
        let duration = end.timeIntervalSince(start)
        
        let entry = HistoryEntry(
            text: sessionText,
            timestamp: end,
            sourceAppName: sourceAppName,
            duration: duration,
            modelTier: modelTier.rawValue
        )
        
        do {
            try historyStore.insert(entry: entry)
        } catch {
            print("Failed to save session history: \(error)")
        }
    }
    
    public func processAudioBuffer(_ samples: [Float]) async {
        bufferProcessor.process(samples: samples)
    }
    
    private func transcribeAndInsert(_ samples: [Float]) async {
        do {
            let context = await screenContextTask?.value
            let transcribed = try await engine.transcribe(audioSamples: samples, sampleRate: 16000, context: context)
            let trimmed = transcribed.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            self.sessionText = self.sessionText.isEmpty ? trimmed : self.sessionText + " " + trimmed
            self.segmentCount += 1

            if textInsertionService.canInsertIntoFocusedElement() {
                try await textInsertionService.insertText(trimmed + " ")
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(self.sessionText, forType: .string)
            }
            
        } catch {
            print("Transcription session segment error: \(error)")
        }
    }
}
