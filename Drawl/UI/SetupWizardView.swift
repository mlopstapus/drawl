import SwiftUI
import AVFoundation

struct SetupWizardView: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var currentStep = 1
    
    @StateObject private var micPermission = MicrophonePermission()
    @StateObject private var accessPermission = AccessibilityPermission()
    @State private var selectedTier: ModelTier = .base
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with App Cover / Icon representation
            VStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .cornerRadius(12)
                    .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text("Welcome to Drawl")
                    .font(.title)
                    .bold()
                
                Text("Let's get you set up in a few simple steps.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // Progress Indicator (Step tracker)
            HStack(spacing: 24) {
                stepIndicator(step: 1, title: "Microphone")
                stepIndicator(step: 2, title: "Accessibility")
                stepIndicator(step: 3, title: "Model Setup")
            }
            .padding(.bottom, 30)
            
            Divider()
            
            // Step Content
            VStack {
                if currentStep == 1 {
                    microphoneStep
                } else if currentStep == 2 {
                    accessibilityStep
                } else {
                    modelSetupStep
                }
            }
            .padding()
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Navigation Footer
            HStack {
                if currentStep > 1 && currentStep < 3 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep == 1 {
                    Button("Next") {
                        withAnimation {
                            currentStep = 2
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!micPermission.isGranted)
                } else if currentStep == 2 {
                    Button("Next") {
                        withAnimation {
                            currentStep = 3
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!accessPermission.isGranted)
                } else {
                    let isDownloaded = appDelegate.modelManager.localPath(for: SpeechModel(tier: selectedTier)) != nil
                    let isDownloading = isDownloadingSelected
                    let buttonTitle = isDownloaded ? "Finish Setup" : (isDownloading ? "Downloading..." : "Start Download")
                    
                    Button(buttonTitle) {
                        if isDownloaded {
                            finishSetup()
                        } else {
                            appDelegate.preferencesStore.selectedModelId = selectedTier.id
                            appDelegate.downloadModel(tier: selectedTier)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    // Disable if downloading another model or current model
                    .disabled(isDownloading || isDownloadingOtherThanSelected)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        }
        .frame(width: 550, height: 620)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
        )
        .onAppear {
            micPermission.checkStatus()
            accessPermission.startPolling()
        }
        .onDisappear {
            accessPermission.stopPolling()
        }
    }
    
    private var isDownloadingOtherThanSelected: Bool {
        if case .modelDownloading = appDelegate.appState {
            return appDelegate.preferencesStore.selectedModelId != selectedTier.id
        }
        return false
    }
    
    private var isDownloadingSelected: Bool {
        if case .modelDownloading = appDelegate.appState {
            return appDelegate.preferencesStore.selectedModelId == selectedTier.id
        }
        return false
    }
    
    private func stepIndicator(step: Int, title: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(currentStep >= step ? Color.purple : Color.secondary.opacity(0.3))
                    .frame(width: 24, height: 24)
                
                if currentStep > step || (step == 1 && micPermission.isGranted) || (step == 2 && accessPermission.isGranted) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(currentStep == step ? .primary : .secondary)
                .bold(currentStep == step)
        }
    }
    
    // Step 1: Microphone
    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundColor(micPermission.isGranted ? .green : .purple)
                .padding()
            
            Text("Microphone Access Required")
                .font(.headline)
            
            Text("Drawl needs microphone access to capture your voice for speech-to-text transcription. Your audio never leaves this device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if micPermission.isGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Access Granted!")
                        .foregroundColor(.green)
                        .bold()
                }
                .padding()
            } else {
                Button("Grant Microphone Access") {
                    micPermission.requestAccess { granted in
                        if granted {
                            withAnimation {
                                currentStep = 2
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding()
            }
        }
    }
    
    // Step 2: Accessibility
    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 48))
                .foregroundColor(accessPermission.isGranted ? .green : .purple)
                .padding()
            
            Text("Accessibility Integration Required")
                .font(.headline)
            
            Text("To insert transcribed text directly into other applications (like Notes, Slack, or Safari), Drawl needs Accessibility API permissions.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if accessPermission.isGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Accessibility Access Trusted!")
                        .foregroundColor(.green)
                        .bold()
                }
                .padding()
            } else {
                Button("Open System Settings") {
                    accessPermission.openSystemSettings()
                    accessPermission.startPolling()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding()
                
                Text("Once settings open, scroll to 'Accessibility' and toggle on 'Drawl'. This wizard will automatically proceed when enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // Step 3: Model Setup
    private var modelSetupStep: some View {
        VStack(spacing: 16) {
            Text("Select Voice Model Tier")
                .font(.headline)
            
            Text("All speech processing is done fully offline. Choose a Whisper model size suitable for your machine:")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
            Picker("", selection: $selectedTier) {
                ForEach(ModelTier.allCases, id: \.self) { tier in
                    Text(tier.displayName).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            let model = SpeechModel(tier: selectedTier)
            let isDownloaded = appDelegate.modelManager.localPath(for: model) != nil
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Details")
                            .font(.subheadline)
                            .bold()
                        Text("Size on disk: \(ByteCountFormatter.string(fromByteCount: selectedTier.fileSizeInBytes, countStyle: .file))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(modelDescription(selectedTier))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(8)
                
                if isDownloaded {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Model is ready to use!")
                            .foregroundColor(.green)
                            .bold()
                    }
                    .padding(.top, 10)
                } else {
                    if case .modelDownloading(let progress) = appDelegate.appState, appDelegate.preferencesStore.selectedModelId == selectedTier.id {
                        VStack(spacing: 6) {
                            if progress == 0.0 {
                                ProgressView()
                                Text("Connecting to server...")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                    .bold()
                            } else {
                                ProgressView(value: progress)
                                    .progressViewStyle(.linear)
                                Text("Downloading: \(Int(progress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                    .bold()
                            }
                        }
                        .padding(.top, 10)
                    } else if case .error(let error) = appDelegate.appState {
                        VStack(spacing: 6) {
                            Text("Error: \(error.localizedDescription)")
                                .font(.caption)
                                .foregroundColor(.red)
                            Button("Retry") {
                                appDelegate.preferencesStore.selectedModelId = selectedTier.id
                                appDelegate.downloadModel(tier: selectedTier)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func modelDescription(_ tier: ModelTier) -> String {
        switch tier {
        case .tiny:
            return "Requires minimal disk space. Extremely fast transcription, but may make minor spelling mistakes."
        case .base:
            return "Recommended for most machines. Excellent balance of speed and accuracy."
        case .small:
            return "Highest accuracy. Requires more memory and processing power. May take longer on older machines."
        }
    }
    
    private func finishSetup() {
        appDelegate.preferencesStore.hasCompletedSetup = true
        appDelegate.checkSetupAndInitialize()
        // Close setup window
        NotificationCenter.default.post(name: .closeSetupWizardWindow, object: nil)
    }
}

extension Notification.Name {
    public static let openSetupWizardWindow = Notification.Name("openSetupWizardWindow")
    public static let closeSetupWizardWindow = Notification.Name("closeSetupWizardWindow")
}
