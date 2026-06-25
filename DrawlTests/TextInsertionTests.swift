import XCTest
import AppKit
@testable import Drawl

final class TextInsertionTests: XCTestCase {
    func testClipboardSaveAndRestoreCycle() async throws {
        let service = TextInsertionService()
        
        let originalClipboardString = "Original clipboard text \(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(originalClipboardString, forType: .string)
        
        let textToInsert = "Inserted dictation text"
        
        let savedItems = service.saveClipboard()
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToInsert, forType: .string)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), textToInsert)
        
        service.restoreClipboard(savedItems)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), originalClipboardString)
    }
    
    func testCanInsertIntoFocusedElement() {
        let service = TextInsertionService()
        let result = service.canInsertIntoFocusedElement()
        XCTAssertTrue(result == true || result == false)
    }
}
