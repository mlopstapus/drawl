import Cocoa
import ApplicationServices

public class TextInsertionService: TextInsertionServiceProtocol {
    public init() {}
    
    public func canInsertIntoFocusedElement() -> Bool {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let element = (focusedElement as! AXUIElement?) else {
            return false
        }
        
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        guard roleResult == .success, let role = roleValue as? String else {
            return false
        }
        
        let textRoles = [
            kAXTextFieldRole,
            kAXTextAreaRole,
            "AXWebArea",
            "AXTextBox"
        ] as [String]
        
        return textRoles.contains(role)
    }
    
    public func insertText(_ text: String) async throws {
        guard !text.isEmpty else { return }
        
        let canInsert = canInsertIntoFocusedElement()
        
        if !canInsert {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            throw AppError.transcriptionFailed("No focused text field. Copied transcription to clipboard.")
        }
        
        let savedItems = saveClipboard()
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        simulatePaste()
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        restoreClipboard(savedItems)
    }
    
    public struct SavedPasteboardItem {
        public let type: NSPasteboard.PasteboardType
        public let data: Data
    }
    
    public func saveClipboard() -> [SavedPasteboardItem] {
        var saved: [SavedPasteboardItem] = []
        guard let items = NSPasteboard.general.pasteboardItems else { return saved }
        
        for item in items {
            for type in item.types {
                if let data = item.data(forType: type) {
                    saved.append(SavedPasteboardItem(type: type, data: data))
                }
            }
        }
        return saved
    }
    
    public func restoreClipboard(_ saved: [SavedPasteboardItem]) {
        NSPasteboard.general.clearContents()
        for item in saved {
            NSPasteboard.general.setData(item.data, forType: item.type)
        }
    }
    
    private func simulatePaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        
        let vKeyDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        vKeyDown?.flags = .maskCommand
        vKeyDown?.post(tap: .cgSessionEventTap)
        
        let vKeyUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        vKeyUp?.flags = .maskCommand
        vKeyUp?.post(tap: .cgSessionEventTap)
    }
}
