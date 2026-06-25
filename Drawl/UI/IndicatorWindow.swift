import Cocoa
import SwiftUI

struct IndicatorView: View {
    @ObservedObject var viewModel: IndicatorViewModel
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 24
                    )
                )
                .scaleEffect(viewModel.isSpeaking ? 1.0 + CGFloat(viewModel.audioLevel * 1.5) : viewModel.pulseScale)
                .opacity(viewModel.pulseOpacity)
                .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple, Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                )
                .shadow(color: Color.purple.opacity(0.6), radius: 6, x: 0, y: 0)
        }
        .frame(width: 48, height: 48)
    }
}

public class IndicatorViewModel: ObservableObject {
    @Published public var isSpeaking = false
    @Published public var audioLevel: Float = 0.0
    @Published public var pulseScale: CGFloat = 1.0
    @Published public var pulseOpacity: Double = 0.8
    
    private var timer: Timer?
    
    public init() {
        startPulseAnimation()
    }
    
    private func startPulseAnimation() {
        var increasing = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, !self.isSpeaking else { return }
            
            let delta = 0.4 / (1.5 / 0.05)
            
            if increasing {
                self.pulseOpacity += delta
                self.pulseScale = CGFloat(1.0 + (self.pulseOpacity - 0.6) * 0.2)
                if self.pulseOpacity >= 1.0 {
                    increasing = false
                }
            } else {
                self.pulseOpacity -= delta
                self.pulseScale = CGFloat(1.0 + (self.pulseOpacity - 0.6) * 0.2)
                if self.pulseOpacity <= 0.6 {
                    increasing = true
                }
            }
        }
    }
    
    public func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.audioLevel = level
            self.isSpeaking = level > 0.05
            if self.isSpeaking {
                self.pulseOpacity = Double(0.6 + level * 0.4)
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

public class IndicatorWindow: NSPanel {
    public let viewModel = IndicatorViewModel()
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 48, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.hasShadow = false
        
        let hostingView = NSHostingView(rootView: IndicatorView(viewModel: viewModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 48, height: 48)
        self.contentView = hostingView
    }
    
    public func show(at position: IndicatorPosition) {
        updatePosition(for: position)
        
        self.alphaValue = 0.0
        self.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 1.0
        }
    }
    
    public func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 0.0
        } completionHandler: {
            self.orderOut(nil)
        }
    }
    
    public func updatePosition(for position: IndicatorPosition) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let point = calculatePosition(for: position, screenFrame: screenFrame)
        self.setFrameOrigin(point)
    }
    
    public func calculatePosition(for position: IndicatorPosition, screenFrame: NSRect) -> NSPoint {
        let size: CGFloat = 48
        let margin: CGFloat = 20
        
        switch position {
        case .nearCursor:
            let mouseLoc = NSEvent.mouseLocation
            return NSPoint(x: mouseLoc.x + 10, y: mouseLoc.y - size - 10)
            
        case .topRight:
            return NSPoint(x: screenFrame.width - size - margin, y: screenFrame.height - size - margin)
            
        case .topLeft:
            return NSPoint(x: margin, y: screenFrame.height - size - margin)
            
        case .bottomRight:
            return NSPoint(x: screenFrame.width - size - margin, y: margin)
            
        case .bottomLeft:
            return NSPoint(x: margin, y: margin)
        }
    }
}
