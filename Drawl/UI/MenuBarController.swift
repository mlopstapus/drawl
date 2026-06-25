import Cocoa
import Combine

public class MenuBarController: NSObject {
    private weak var appDelegate: AppDelegate?
    private var statusItem: NSStatusItem?
    public let statusMenu = NSMenu()
    private var cancellables = Set<AnyCancellable>()
    
    private var statusItemLabel: NSMenuItem!
    private var relaunchSetupItem: NSMenuItem!
    private var toggleDictationItem: NSMenuItem!
    private var historyItem: NSMenuItem!
    private var preferencesItem: NSMenuItem!
    private var quitItem: NSMenuItem!
    
    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        
        setupMenuBar()
        setupMenu()
        observeAppState()
    }
    
    private func setupMenuBar() {
        if NSClassFromString("XCTestCase") == nil {
            NSLog("[MenuBarController] setupMenuBar starting")
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem?.button {
                if let logoImage = NSImage(named: "AppLogo") {
                    NSLog("[MenuBarController] Successfully loaded AppLogo: size = \(logoImage.size)")
                    let size = NSSize(width: 18, height: 18)
                    let resizedImage = NSImage(size: size)
                    resizedImage.lockFocus()
                    logoImage.draw(in: NSRect(origin: .zero, size: size))
                    resizedImage.unlockFocus()
                    resizedImage.isTemplate = true
                    button.image = resizedImage
                    NSLog("[MenuBarController] Set button.image to resized AppLogo (template)")
                } else {
                    NSLog("[MenuBarController] AppLogo was not found in assets, falling back to system symbol")
                    button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Drawl")
                    button.image?.isTemplate = true
                }
            } else {
                NSLog("[MenuBarController] Failed to get statusItem button")
            }
            statusItem?.menu = statusMenu
        }
    }
    
    private func setupMenu() {
        statusItemLabel = NSMenuItem(title: "Status: Initializing", action: nil, keyEquivalent: "")
        statusItemLabel.isEnabled = false
        statusMenu.addItem(statusItemLabel)
        
        relaunchSetupItem = NSMenuItem(title: "Relaunch Setup Wizard...", action: #selector(relaunchSetup), keyEquivalent: "")
        relaunchSetupItem.target = self
        relaunchSetupItem.isHidden = true
        statusMenu.addItem(relaunchSetupItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        toggleDictationItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: "")
        toggleDictationItem.target = self
        statusMenu.addItem(toggleDictationItem)
        
        historyItem = NSMenuItem(title: "Transcription History", action: #selector(openHistory), keyEquivalent: "h")
        historyItem.target = self
        statusMenu.addItem(historyItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        statusMenu.addItem(preferencesItem)
        
        quitItem = NSMenuItem(title: "Quit Drawl", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }
    
    private func observeAppState() {
        appDelegate?.$appState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleStateChange(_ state: AppState) {
        updateStatusLabel(for: state)
        
        switch state {
        case .setupRequired:
            toggleDictationItem.isEnabled = false
            toggleDictationItem.title = "Start Dictation"
            historyItem.isEnabled = false
            relaunchSetupItem.isHidden = false
        case .idle:
            toggleDictationItem.isEnabled = true
            toggleDictationItem.title = "Start Dictation"
            historyItem.isEnabled = true
            relaunchSetupItem.isHidden = true
        case .listening:
            toggleDictationItem.isEnabled = true
            toggleDictationItem.title = "Stop Dictation"
            historyItem.isEnabled = true
            relaunchSetupItem.isHidden = true
        case .processing:
            toggleDictationItem.isEnabled = false
            toggleDictationItem.title = "Processing…"
            historyItem.isEnabled = true
            relaunchSetupItem.isHidden = true
        case .modelDownloading(let progress):
            toggleDictationItem.isEnabled = false
            toggleDictationItem.title = "Downloading Model (\(Int(progress * 100))%)"
            historyItem.isEnabled = false
            relaunchSetupItem.isHidden = true
        case .error(let error):
            toggleDictationItem.isEnabled = false
            toggleDictationItem.title = "Error: \(error.localizedDescription)"
            historyItem.isEnabled = true
            relaunchSetupItem.isHidden = false
        }
    }
    
    public func updateStatusLabel() {
        if let state = appDelegate?.appState {
            updateStatusLabel(for: state)
        }
    }
    
    private func updateStatusLabel(for state: AppState) {
        switch state {
        case .setupRequired:
            statusItemLabel.title = "Status: Setup Required"
        case .idle:
            statusItemLabel.title = "Status: Idle"
        case .listening:
            statusItemLabel.title = "Status: Listening…"
        case .processing:
            statusItemLabel.title = "Status: Processing…"
        case .modelDownloading(let progress):
            statusItemLabel.title = "Status: Downloading (\(Int(progress * 100))%)"
        case .error:
            statusItemLabel.title = "Status: Error"
        }
    }
    
    @objc private func toggleDictation() {
        guard let appDelegate = appDelegate else { return }
        if appDelegate.appState == .listening {
            appDelegate.stopDictation()
        } else if appDelegate.appState == .idle {
            appDelegate.startDictation()
        }
    }
    
    @objc private func openHistory() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openHistoryWindow, object: nil)
    }
    
    @objc private func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openPreferencesWindow, object: nil)
    }
    
    @objc private func relaunchSetup() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openSetupWizardWindow, object: nil)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    public static let openHistoryWindow = Notification.Name("openHistoryWindow")
    public static let openPreferencesWindow = Notification.Name("openPreferencesWindow")
}
