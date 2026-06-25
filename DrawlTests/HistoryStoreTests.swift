import XCTest
import GRDB
@testable import Drawl

final class HistoryStoreTests: XCTestCase {
    var dbQueue: DatabaseQueue!
    var store: HistoryStore!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        dbQueue = try DatabaseQueue()
        store = try HistoryStore(databaseWriter: dbQueue)
    }
    
    func testInsertAndFetchAll() throws {
        XCTAssertEqual(try store.count(), 0)
        
        let entry1 = HistoryEntry(
            text: "Hello world",
            timestamp: Date().addingTimeInterval(-10),
            sourceAppName: "Notes",
            duration: 2.5,
            modelTier: "base"
        )
        
        let entry2 = HistoryEntry(
            text: "Test transcription",
            timestamp: Date(),
            sourceAppName: "Safari",
            duration: 1.8,
            modelTier: "tiny"
        )
        
        try store.insert(entry: entry1)
        try store.insert(entry: entry2)
        
        XCTAssertEqual(try store.count(), 2)
        
        let fetched = try store.fetchAll()
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched[0].text, "Test transcription")
        XCTAssertEqual(fetched[1].text, "Hello world")
    }
    
    func testSearch() throws {
        let entry1 = HistoryEntry(text: "Apple apple banana", duration: 1.0, modelTier: "base")
        let entry2 = HistoryEntry(text: "Banana cherry", duration: 1.0, modelTier: "base")
        let entry3 = HistoryEntry(text: "Cherry apple", duration: 1.0, modelTier: "base")
        
        try store.insert(entry: entry1)
        try store.insert(entry: entry2)
        try store.insert(entry: entry3)
        
        let appleResults = try store.search(query: "apple")
        XCTAssertEqual(appleResults.count, 2)
        
        let cherryResults = try store.search(query: "cherry")
        XCTAssertEqual(cherryResults.count, 2)
        
        let bananaResults = try store.search(query: "banana")
        XCTAssertEqual(bananaResults.count, 2)
    }
    
    func testPurgeOldEntries() throws {
        let calendar = Calendar.current
        let today = Date()
        let oldDate = calendar.date(byAdding: .day, value: -31, to: today)!
        let recentDate = calendar.date(byAdding: .day, value: -29, to: today)!
        
        let oldEntry = HistoryEntry(text: "Old entry", timestamp: oldDate, duration: 1.0, modelTier: "base")
        let recentEntry = HistoryEntry(text: "Recent entry", timestamp: recentDate, duration: 1.0, modelTier: "base")
        
        try store.insert(entry: oldEntry)
        try store.insert(entry: recentEntry)
        
        XCTAssertEqual(try store.count(), 2)
        
        try store.purgeOldEntries(olderThanDays: 30)
        
        XCTAssertEqual(try store.count(), 1)
        let fetched = try store.fetchAll()
        XCTAssertEqual(fetched[0].text, "Recent entry")
    }
}
