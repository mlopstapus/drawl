import SwiftUI

public struct ShortcutFormatter {
    public static func string(keyCode: UInt16, modifiers: UInt64) -> String {
        var result = ""
        if (modifiers & 262144) != 0 { result += "⌃" }   // Control
        if (modifiers & 524288) != 0 { result += "⌥" }   // Option
        if (modifiers & 131072) != 0 { result += "⇧" }   // Shift
        if (modifiers & 1048576) != 0 { result += "⌘" }  // Command
        
        switch keyCode {
        case 36: result += "↩"
        case 48: result += "⇥"
        case 49: result += "Space"
        case 51: result += "⌫"
        case 53: result += "⎋"
        case 123: result += "←"
        case 124: result += "→"
        case 125: result += "↓"
        case 126: result += "↑"
        default:
            let keyMap: [UInt16: String] = [
                0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
                11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
                18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
                27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
                37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
                46: "M", 47: ".", 50: "`"
            ]
            result += keyMap[keyCode] ?? "Key \(keyCode)"
        }
        return result
    }
}

struct ShortcutRecorderView: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt64
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack {
                if isRecording {
                    Text("Press Hotkey...")
                        .foregroundColor(.purple)
                        .bold()
                } else {
                    Text(ShortcutFormatter.string(keyCode: keyCode, modifiers: modifiers))
                        .bold()
                }
                Spacer()
                Image(systemName: "keyboard")
                    .foregroundColor(isRecording ? .purple : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRecording ? Color.purple.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecording ? Color.purple : Color.secondary.opacity(0.2), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                if event.keyCode == 53 { // Escape
                    stopRecording()
                    return nil
                }
                
                let rawFlags = event.modifierFlags.rawValue
                let filteredFlags = rawFlags & (NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue)
                
                self.keyCode = event.keyCode
                self.modifiers = UInt64(filteredFlags)
                stopRecording()
                return nil
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var appDelegate: AppDelegate
    @ObservedObject var preferencesStore: PreferencesStore
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        self.preferencesStore = appDelegate.preferencesStore
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Section 1: Activation
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.purple)
                        Text("Activation Shortcut")
                            .font(.headline)
                    }
                    Text("Hold this hotkey to dictate. Release to insert text.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ShortcutRecorderView(
                        keyCode: Binding(
                            get: { preferencesStore.hotkeyKeyCode },
                            set: { preferencesStore.hotkeyKeyCode = $0 }
                        ),
                        modifiers: Binding(
                            get: { preferencesStore.hotkeyModifiers },
                            set: { preferencesStore.hotkeyModifiers = $0 }
                        )
                    )
                    .frame(width: 220)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                // Section 2: Model settings
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(.purple)
                        Text("Whisper Model")
                            .font(.headline)
                    }
                    
                    Text("Select your preferred voice transcription model. Larger models are more accurate but use more storage and memory.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(ModelTier.allCases, id: \.self) { tier in
                        let model = SpeechModel(tier: tier)
                        let isDownloaded = appDelegate.modelManager.localPath(for: model) != nil
                        let isSelected = preferencesStore.selectedModelId == tier.id
                        
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(tier.displayName)
                                            .font(.body)
                                            .bold()
                                        if isSelected {
                                            Text("Active")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple.opacity(0.2))
                                                .foregroundColor(.purple)
                                                .cornerRadius(6)
                                        }
                                    }
                                    Text(ByteCountFormatter.string(fromByteCount: tier.fileSizeInBytes, countStyle: .file))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                if isDownloaded {
                                    HStack(spacing: 12) {
                                        if !isSelected {
                                            Button("Activate") {
                                                preferencesStore.selectedModelId = tier.id
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        
                                        Button(action: {
                                            try? appDelegate.modelManager.delete(model: model)
                                            appDelegate.checkSetupAndInitialize()
                                            // Force view refresh
                                            self.preferencesStore.objectWillChange.send()
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isSelected)
                                    }
                                } else {
                                    if case .modelDownloading = appDelegate.appState, isSelected {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Button("Download") {
                                            preferencesStore.selectedModelId = tier.id
                                            appDelegate.downloadModel(tier: tier)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.purple)
                                    }
                                }
                            }
                            
                            if isSelected, case .modelDownloading(let progress) = appDelegate.appState {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: progress)
                                        .progressViewStyle(.linear)
                                    Text("Downloading: \(Int(progress * 100))%")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.purple.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                // Section 3: Settings
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.purple)
                        Text("General Settings")
                            .font(.headline)
                    }
                    
                    Toggle(isOn: Binding(
                        get: { preferencesStore.launchAtLogin },
                        set: { preferencesStore.launchAtLogin = $0 }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Launch at Login")
                            Text("Automatically start Drawl when you log in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Floating Indicator Position")
                        Picker("", selection: Binding(
                            get: { preferencesStore.indicatorPosition },
                            set: { preferencesStore.indicatorPosition = $0 }
                        )) {
                            Text("Near Cursor").tag(IndicatorPosition.nearCursor)
                            Text("Top Right").tag(IndicatorPosition.topRight)
                            Text("Top Left").tag(IndicatorPosition.topLeft)
                            Text("Bottom Right").tag(IndicatorPosition.bottomRight)
                            Text("Bottom Left").tag(IndicatorPosition.bottomLeft)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("History Retention")
                        Picker("", selection: Binding(
                            get: { preferencesStore.historyRetentionDays },
                            set: { preferencesStore.historyRetentionDays = $0 }
                        )) {
                            Text("7 Days").tag(7)
                            Text("15 Days").tag(15)
                            Text("30 Days").tag(30)
                            Text("90 Days").tag(90)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Divider()
                    
                    Button("Re-run Setup Wizard") {
                        preferencesStore.hasCompletedSetup = false
                        appDelegate.checkSetupAndInitialize()
                        // Notify app to present setup wizard
                        NotificationCenter.default.post(name: .openSetupWizardWindow, object: nil)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            .padding()
        }
        .frame(width: 480, height: 580)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
