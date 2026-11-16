import Foundation
import GRDB

/// Owns the SQLite database file and its schema (≈ DatabaseManager + the ensure…() migrations).
///
/// Unlike the Android app, the schema has numbered migrations: each runs exactly once, in order,
/// and GRDB records which ones already ran. A future version adds "v2", "v3", … and never edits
/// an existing migration.
nonisolated final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try AppDatabase.migrator.migrate(writer)
    }

    /// The real database: Application Support/Database/masebha.sqlite (included in iCloud backups).
    static func openDefault() throws -> AppDatabase {
        try open(at: defaultURL())
    }

    static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let queue = try DatabaseQueue(path: url.path, configuration: configuration())
        return try AppDatabase(queue)
    }

    /// A fresh database in memory, for unit tests.
    static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue(configuration: configuration()))
    }

    static func defaultURL() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        return support.appendingPathComponent("Database", isDirectory: true)
            .appendingPathComponent("masebha.sqlite")
    }

    private static func configuration() -> Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = true  // deleting a dhikr also deletes its daily counts
        config.label = "Masebha"
        return config
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE dhikr (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    total INTEGER NOT NULL DEFAULT 0 CHECK (total >= 0),
                    loopSize INTEGER NOT NULL CHECK (loopSize > 0),
                    position INTEGER NOT NULL,
                    lastOpenedAt INTEGER,
                    timerDelayMs INTEGER NOT NULL DEFAULT 1000 CHECK (timerDelayMs >= 100)
                );
                CREATE TABLE dailyCount (
                    dhikrId INTEGER NOT NULL REFERENCES dhikr(id) ON DELETE CASCADE,
                    day TEXT NOT NULL,
                    count INTEGER NOT NULL DEFAULT 0 CHECK (count >= 0),
                    PRIMARY KEY (dhikrId, day)
                ) WITHOUT ROWID;
                """)
        }

        return migrator
    }
}
