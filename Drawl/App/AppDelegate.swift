import AppKit
import Combine
import AVFoundation
import ServiceManagement
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published public var appState: AppState = .setupRequired
    
    public var preferencesStore = PreferencesStore()
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
    public var loadedModelTier: ModelTier?
    
    private var setupWizardWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var historyWindow: NSWindow?
    
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
        
        preferencesStore.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.preferencesChanged()
                }
            }
            .store(in: &cancellables)
        
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
        
        hotkeyManager.onHotkeyCancel = { [weak self] in
            self?.cancelDictation()
        }
        
        NotificationCenter.default.publisher(for: .openSetupWizardWindow)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showSetupWizardWindow()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .closeSetupWizardWindow)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.closeSetupWizardWindow()
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .openPreferencesWindow)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showPreferencesWindow()
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .openHistoryWindow)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showHistoryWindow()
                }
            }
            .store(in: &cancellables)
        
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
            DispatchQueue.main.async {
                self.showSetupWizardWindow()
            }
            return
        }
        
        preferencesStore.hasCompletedSetup = true
        Task {
            await loadActiveModelAndRegisterHotkey(tier: selectedModelTier)
        }
    }
    
    public func downloadModel(tier: ModelTier) {
        let model = SpeechModel(tier: tier)
        Task {
            do {
                DispatchQueue.main.async {
                    self.appState = .modelDownloading(progress: 0.0)
                }
                try await modelManager.download(model: model) { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.appState = .modelDownloading(progress: progress)
                    }
                }
                
                // Once downloaded, let's load it and transition to idle
                await loadActiveModelAndRegisterHotkey(tier: tier)
                checkSetupAndInitialize()
            } catch {
                DispatchQueue.main.async {
                    self.appState = .error(.modelDownloadFailed(error.localizedDescription))
                }
            }
        }
    }
    
    public func preferencesChanged() {
        registerHotkey()
        updateLaunchAtLogin(enabled: preferencesStore.launchAtLogin)
        
        let selectedModelTier = ModelTier.allCases.first { $0.id == preferencesStore.selectedModelId } ?? .base
        if loadedModelTier != selectedModelTier {
            let model = SpeechModel(tier: selectedModelTier)
            if modelManager.localPath(for: model) != nil {
                Task {
                    await loadActiveModelAndRegisterHotkey(tier: selectedModelTier)
                }
            } else {
                self.appState = .setupRequired
                preferencesStore.hasCompletedSetup = false
            }
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
                self.loadedModelTier = tier
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
        guard AXIsProcessTrusted() || NSClassFromString("XCTestCase") != nil else {
            print("Skipping hotkey registration: Accessibility permission not granted yet.")
            return
        }
        
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
    
    public func cancelDictation() {
        guard appState == .listening else { return }
        
        self.appState = .idle
        audioCaptureManager.stop()
        
        self.indicatorWindow?.hide()
        self.indicatorWindow = nil
        
        currentSession = nil
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
    
    public func showSetupWizardWindow() {
        guard NSClassFromString("XCTestCase") == nil else { return }
        if let window = setupWizardWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Drawl Setup Wizard"
        window.center()
        window.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: SetupWizardView(appDelegate: self))
        window.contentView = hostingView
        
        self.setupWizardWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func closeSetupWizardWindow() {
        setupWizardWindow?.close()
        setupWizardWindow = nil
    }
    
    public func showPreferencesWindow() {
        guard NSClassFromString("XCTestCase") == nil else { return }
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Drawl Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: PreferencesView(appDelegate: self))
        window.contentView = hostingView
        
        self.preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func showHistoryWindow() {
        guard NSClassFromString("XCTestCase") == nil else { return }
        if let window = historyWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Drawl Transcription History"
        window.center()
        window.isReleasedWhenClosed = false
        
        let viewModel = HistoryViewModel(store: historyStore, preferencesStore: preferencesStore)
        let hostingView = NSHostingView(rootView: HistoryView(viewModel: viewModel))
        window.contentView = hostingView
        
        self.historyWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
