import XCTest
import AppKit
@testable import Drawl

final class MenuBarControllerTests: XCTestCase {
    func testMenuSetup() {
        let appDelegate = AppDelegate()
        let controller = MenuBarController(appDelegate: appDelegate)
        
        let menu = controller.statusMenu
        
        XCTAssertEqual(menu.items.count, 7)
        XCTAssertTrue(menu.items[0].title.contains("Status:"))
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[2].title, "Start Dictation")
        XCTAssertEqual(menu.items[3].title, "Transcription History")
        XCTAssertTrue(menu.items[4].isSeparatorItem)
        XCTAssertEqual(menu.items[5].title, "Preferences…")
        XCTAssertEqual(menu.items[6].title, "Quit Drawl")
    }
    
    func testStatusUpdateOnStateChange() {
        let appDelegate = AppDelegate()
        let controller = MenuBarController(appDelegate: appDelegate)
        
        appDelegate.appState = .idle
        controller.updateStatusLabel()
        XCTAssertEqual(controller.statusMenu.items[0].title, "Status: Idle")
        
        appDelegate.appState = .listening
        controller.updateStatusLabel()
        XCTAssertEqual(controller.statusMenu.items[0].title, "Status: Listening…")
        
        appDelegate.appState = .processing
        controller.updateStatusLabel()
        XCTAssertEqual(controller.statusMenu.items[0].title, "Status: Processing…")
    }
}
