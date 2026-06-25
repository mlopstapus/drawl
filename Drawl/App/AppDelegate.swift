import AppKit
import Combine
import AVFoundation
import ServiceManagement

public class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published public var appState: AppState = .setupRequired
    
    public let preferencesStore = PreferencesStore()
    public let modelManager = ModelManager()
    public var historyStore: HistoryStore!
    
    public let hotkeyManager = HotkeyManager()
    public let audioCaptureManager = AudioCaptureManager()
    public let whisperEngine = WhisperEngine()
    public let textInsertionService = TextInsertionService()
    
    private var currentSession: TranscriptionSession?
    private var menuBarController: MenuBarController?
    private var indicatorWindow: IndicatorWindow?
    private var cancellables = Set<AnyCancellable>()
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        do {
            self.historyStore = try HistoryStore()
        } catch {
            print("Failed to initialize HistoryStore: \(error)")
            self.appState = .error(.transcriptionFailed("Failed to initialize local database: \(error.localizedDescription)"))
            return
        }
        
        self.menuBarController = MenuBarController(appDelegate: self)
        updateLaunchAtLogin(enabled: preferencesStore.launchAtLogin)
        
        audioCaptureManager.onAudioBuffer = { [weak self] samples in
            guard let self = self else { return }
            if self.appState == .listening {
                let volume = self.calculateVolumeLevel(samples)
                self.indicatorWindow?.viewModel.updateAudioLevel(volume)
                Task {
                    await self.currentSession?.processAudioBuffer(samples)
                }
            }
        }
        
        hotkeyManager.onHotkeyDown = { [weak self] in
            self?.startDictation()
        }
        
        hotkeyManager.onHotkeyUp = { [weak self] in
            self?.stopDictation()
        }
        
        checkSetupAndInitialize()
    }
    
    public func checkSetupAndInitialize() {
        let hasMic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let hasAccessibility = AXIsProcessTrusted()
        
        let selectedModelTier = ModelTier.allCases.first { $0.id == preferencesStore.selectedModelId } ?? .base
        let models = modelManager.availableModels()
        let selectedModel = models.first { $0.id == preferencesStore.selectedModelId }
        let hasModel = selectedModel?.isDownloaded ?? false
        
        if !hasMic || !hasAccessibility || !hasModel {
            self.appState = .setupRequired
            preferencesStore.hasCompletedSetup = false
            return
        }
        
        preferencesStore.hasCompletedSetup = true
        Task {
            await loadActiveModelAndRegisterHotkey(tier: selectedModelTier)
        }
    }
    
    public func loadActiveModelAndRegisterHotkey(tier: ModelTier) async {
        guard let modelPath = modelManager.localPath(for: SpeechModel(tier: tier)) else {
            DispatchQueue.main.async {
                self.appState = .setupRequired
            }
            return
        }
        
        do {
            DispatchQueue.main.async {
                self.appState = .modelDownloading(progress: 0.0)
            }
            try await whisperEngine.loadModel(at: modelPath)
            
            DispatchQueue.main.async {
                self.appState = .idle
                self.registerHotkey()
            }
        } catch {
            DispatchQueue.main.async {
                self.appState = .error(.modelLoadFailed("Failed to load model: \(error.localizedDescription)"))
            }
        }
    }
    
    public func registerHotkey() {
        hotkeyManager.unregister()
        do {
            try hotkeyManager.register(
                keyCode: preferencesStore.hotkeyKeyCode,
                modifiers: preferencesStore.hotkeyModifiers
            )
        } catch {
            print("Hotkey registration error: \(error)")
            self.appState = .error(.hotkeyConflict)
        }
    }
    
    public func startDictation() {
        guard appState == .idle else { return }
        
        let selectedModelTier = ModelTier.allCases.first { $0.id == preferencesStore.selectedModelId } ?? .base
        currentSession = TranscriptionSession(
            engine: whisperEngine,
            textInsertionService: textInsertionService,
            historyStore: historyStore,
            modelTier: selectedModelTier
        )
        
        currentSession?.start()
        
        self.indicatorWindow = IndicatorWindow()
        self.indicatorWindow?.show(at: preferencesStore.indicatorPosition)
        
        do {
            try audioCaptureManager.start()
            self.appState = .listening
        } catch {
            print("Failed to start audio recording: \(error)")
            self.indicatorWindow?.hide()
            self.indicatorWindow = nil
            self.appState = .error(.transcriptionFailed("Failed to start audio recording: \(error.localizedDescription)"))
        }
    }
    
    public func stopDictation() {
        guard appState == .listening else { return }
        
        self.appState = .processing
        audioCaptureManager.stop()
        
        self.indicatorWindow?.hide()
        self.indicatorWindow = nil
        
        let session = currentSession
        currentSession = nil
        
        Task {
            await session?.stop()
            DispatchQueue.main.async {
                if case .processing = self.appState {
                    self.appState = .idle
                }
            }
        }
    }
    
    private func calculateVolumeLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        let sumOfSquares = samples.reduce(0.0) { $0 + ($1 * $1) }
        let rms = sqrt(sumOfSquares / Float(samples.count))
        return min(max(rms * 5.0, 0.0), 1.0)
    }
    
    public func updateLaunchAtLogin(enabled: Bool) {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                do {
                    try service.register()
                } catch {
                    print("Failed to register SMAppService: \(error)")
                }
            }
        } else {
            if service.status == .enabled {
                do {
                    try service.unregister()
                } catch {
                    print("Failed to unregister SMAppService: \(error)")
                }
            }
        }
    }
}
