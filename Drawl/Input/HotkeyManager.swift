import Cocoa
import ApplicationServices

public class HotkeyManager: HotkeyManagerProtocol {
    public var onHotkeyDown: (() -> Void)?
    public var onHotkeyUp: (() -> Void)?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private var targetKeyCode: UInt16 = 49 // Default Space
    private var targetModifiers: CGEventFlags = .maskAlternate // Default Option
    
    private var isKeyPressed = false
    
    public init() {}
    
    deinit {
        unregister()
    }
    
    public func register(keyCode: UInt16, modifiers: UInt64) throws {
        unregister()
        
        self.targetKeyCode = keyCode
        
        var flags: CGEventFlags = []
        if (modifiers & 524288) != 0 { flags.insert(.maskAlternate) }
        if (modifiers & 1048576) != 0 { flags.insert(.maskCommand) }
        if (modifiers & 262144) != 0 { flags.insert(.maskControl) }
        if (modifiers & 131072) != 0 { flags.insert(.maskShift) }
        self.targetModifiers = flags
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | 
                        (1 << CGEventType.keyUp.rawValue) | 
                        (1 << CGEventType.flagsChanged.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                
                if manager.handleCGEvent(type: type, event: event) {
                    return nil // Consume event
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPointer
        ) else {
            throw AppError.accessibilityDenied
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    public func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        isKeyPressed = false
    }
    
    @discardableResult
    public func handleEvent(type: CGEventType, keyCode: UInt16, modifierFlags: UInt64) -> Bool {
        var flags: CGEventFlags = []
        if (modifierFlags & 524288) != 0 { flags.insert(.maskAlternate) }
        if (modifierFlags & 1048576) != 0 { flags.insert(.maskCommand) }
        if (modifierFlags & 262144) != 0 { flags.insert(.maskControl) }
        if (modifierFlags & 131072) != 0 { flags.insert(.maskShift) }
        
        return processEvent(type: type, keyCode: keyCode, flags: flags)
    }
    
    private func handleCGEvent(type: CGEventType, event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        return processEvent(type: type, keyCode: keyCode, flags: flags)
    }
    
    private func processEvent(type: CGEventType, keyCode: UInt16, flags: CGEventFlags) -> Bool {
        if type == .flagsChanged {
            if isKeyPressed {
                let modifierMatched = flags.contains(targetModifiers)
                if !modifierMatched {
                    isKeyPressed = false
                    onHotkeyUp?()
                    return true
                }
            }
            return false
        }
        
        guard keyCode == targetKeyCode else { return false }
        
        let modifierMatched = flags.contains(targetModifiers)
        guard modifierMatched else { return false }
        
        if type == .keyDown {
            if !isKeyPressed {
                isKeyPressed = true
                onHotkeyDown?()
            }
            return true
        } else if type == .keyUp {
            if isKeyPressed {
                isKeyPressed = false
                onHotkeyUp?()
            }
            return true
        }
        
        return false
    }
}
