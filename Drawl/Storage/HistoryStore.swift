import Foundation
import GRDB

public struct HistoryEntry: Identifiable, Codable, FetchableRecord, MutablePersistableRecord, TableRecord, Equatable {
    public static let databaseTableName = "historyEntry"
    
    public var id: UUID
    public var text: String
    public var timestamp: Date
    public var sourceAppName: String?
    public var duration: TimeInterval
    public var modelTier: String
    
    public init(id: UUID = UUID(), text: String, timestamp: Date = Date(), sourceAppName: String? = nil, duration: TimeInterval, modelTier: String) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.sourceAppName = sourceAppName
        self.duration = duration
        self.modelTier = modelTier
    }
}

public class HistoryStore {
    private let dbQueue: DatabaseWriter
    
    public init(databaseWriter: DatabaseWriter) throws {
        self.dbQueue = databaseWriter
        try migrator.migrate(dbQueue)
    }
    
    public convenience init(storeDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Drawl")) throws {
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        let dbURL = storeDirectory.appendingPathComponent("history.sqlite")
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        try self.init(databaseWriter: dbQueue)
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createHistoryEntry") { db in
            try db.create(table: "historyEntry") { t in
                t.column("id", .text).primaryKey()
                t.column("text", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("sourceAppName", .text)
                t.column("duration", .double).notNull()
                t.column("modelTier", .text).notNull()
            }
        }
        
        return migrator
    }
    
    public func insert(entry: HistoryEntry) throws {
        try dbQueue.write { db in
            var mutableEntry = entry
            try mutableEntry.insert(db)
        }
    }
    
    public func fetchAll() throws -> [HistoryEntry] {
        try dbQueue.read { db in
            try HistoryEntry.order(Column("timestamp").desc).fetchAll(db)
        }
    }
    
    public func search(query: String) throws -> [HistoryEntry] {
        try dbQueue.read { db in
            try HistoryEntry
                .filter(Column("text").like("%\(query)%"))
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }
    
    public func purgeOldEntries(olderThanDays days: Int) throws {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        _ = try dbQueue.write { db in
            try HistoryEntry
                .filter(Column("timestamp") < cutoffDate)
                .deleteAll(db)
        }
    }
    
    public func count() throws -> Int {
        try dbQueue.read { db in
            try HistoryEntry.fetchCount(db)
        }
    }
}
