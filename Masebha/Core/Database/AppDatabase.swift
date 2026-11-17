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

        // Wird (supporter feature): same tables and meaning as Android's wird / wird_item / wird_day,
        // so backups map one to one. Times are epoch milliseconds (0 = never).
        migrator.registerMigration("v2") { db in
            try db.execute(sql: """
                CREATE TABLE wird (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    createdAt INTEGER NOT NULL DEFAULT 0,
                    lastOpenedAt INTEGER NOT NULL DEFAULT 0,
                    deleted INTEGER NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1))
                );
                CREATE TABLE wirdItem (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    wirdId INTEGER NOT NULL REFERENCES wird(id) ON DELETE CASCADE,
                    position INTEGER NOT NULL DEFAULT 0,
                    body TEXT NOT NULL,
                    target INTEGER NOT NULL CHECK (target > 0),
                    timerDelayMs INTEGER NOT NULL DEFAULT 1000 CHECK (timerDelayMs >= 100),
                    totalTaps INTEGER NOT NULL DEFAULT 0 CHECK (totalTaps >= 0),
                    count INTEGER NOT NULL DEFAULT 0 CHECK (count >= 0),
                    status INTEGER NOT NULL DEFAULT 0 CHECK (status IN (0, 1, 2))
                );
                CREATE INDEX wirdItem_wirdId ON wirdItem(wirdId);
                CREATE TABLE wirdDay (
                    wirdId INTEGER NOT NULL REFERENCES wird(id) ON DELETE CASCADE,
                    day TEXT NOT NULL,
                    state INTEGER NOT NULL DEFAULT 0 CHECK (state IN (0, 1, 2)),
                    taps INTEGER NOT NULL DEFAULT 0 CHECK (taps >= 0),
                    completedAt INTEGER NOT NULL DEFAULT 0,
                    lastActivityAt INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (wirdId, day)
                ) WITHOUT ROWID;
                """)
        }

        return migrator
    }
}
