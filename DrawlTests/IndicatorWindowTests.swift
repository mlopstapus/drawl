import XCTest
import AppKit
@testable import Drawl

final class IndicatorWindowTests: XCTestCase {
    func testWindowConfiguration() {
        let window = IndicatorWindow()
        
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
        XCTAssertEqual(window.level, .floating)
        XCTAssertTrue(window.ignoresMouseEvents)
    }
    
    func testPositioning() {
        let window = IndicatorWindow()
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        let topRight = window.calculatePosition(for: .topRight, screenFrame: screenFrame)
        XCTAssertEqual(topRight.x, screenFrame.width - 48 - 20)
        XCTAssertEqual(topRight.y, screenFrame.height - 48 - 20)
        
        let bottomLeft = window.calculatePosition(for: .bottomLeft, screenFrame: screenFrame)
        XCTAssertEqual(bottomLeft.x, 20)
        XCTAssertEqual(bottomLeft.y, 20)
    }
}
