import Foundation
import GRDB

/// The SQL behind backup and restore.
nonisolated final class BackupStore: Sendable {
    private let database: AppDatabase
    private var writer: any DatabaseWriter { database.writer }

    init(database: AppDatabase) {
        self.database = database
    }

    /// What a backup holds: every dhikr, and the wird tables if the user ever had a wird.
    ///
    /// Without any wird row the section is left out, so importing the file on Android never
    /// replaces that phone's wirds with an empty list.
    func read() throws -> (dhikr: [Dhikr], wird: WirdBackup?) {
        try writer.read { db in
            let dhikr = try Dhikr.fetchAll(db, sql: "SELECT * FROM dhikr ORDER BY position, id")
            let wirds = try Row.fetchAll(db, sql: "SELECT * FROM wird ORDER BY id").map { row in
                WirdBackup.Wird(id: row["id"], name: row["name"], position: row["position"], createdAt: row["createdAt"],
                                lastOpenedAt: row["lastOpenedAt"], deleted: row["deleted"])
            }
            guard !wirds.isEmpty else { return (dhikr, nil) }
            let items = try Row.fetchAll(db, sql: "SELECT * FROM wirdItem ORDER BY id").map { row in
                WirdBackup.Item(id: row["id"], wirdID: row["wirdId"], position: row["position"], body: row["body"],
                                target: row["target"], timerDelayMs: row["timerDelayMs"], totalTaps: row["totalTaps"],
                                count: row["count"], status: row["status"])
            }
            let days = try Row.fetchAll(db, sql: "SELECT * FROM wirdDay ORDER BY wirdId, day").map { row in
                WirdBackup.Day(wirdID: row["wirdId"], day: row["day"], state: row["state"], taps: row["taps"],
                               completedAt: row["completedAt"], lastActivityAt: row["lastActivityAt"])
            }
            return (dhikr, WirdBackup(wirds: wirds, items: items, days: days))
        }
    }

    /// Replaces the adhkar (their daily counts go too, like Android), and all wird data when the
    /// backup has a wird section. One transaction: on any error nothing at all changes.
    func replace(dhikr: [Dhikr], wird: WirdBackup?) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM dhikr")
            for item in dhikr {
                try db.execute(sql: """
                    INSERT INTO dhikr (id, name, total, loopSize, position, lastOpenedAt, timerDelayMs)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [item.id, item.name, item.total, item.loopSize, item.position,
                                     item.lastOpenedAt.map(WirdStore.ms), item.timerDelayMs])
            }
            guard let wird else { return }
            try db.execute(sql: "DELETE FROM wirdDay")
            try db.execute(sql: "DELETE FROM wirdItem")
            try db.execute(sql: "DELETE FROM wird")
            for row in wird.wirds {
                try db.execute(sql: """
                    INSERT INTO wird (id, name, position, createdAt, lastOpenedAt, deleted) VALUES (?, ?, ?, ?, ?, ?)
                    """, arguments: [row.id, row.name, row.position, row.createdAt, row.lastOpenedAt, row.deleted])
            }
            for row in wird.items {
                try db.execute(sql: """
                    INSERT INTO wirdItem (id, wirdId, position, body, target, timerDelayMs, totalTaps, count, status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [row.id, row.wirdID, row.position, row.body, row.target, row.timerDelayMs,
                                     row.totalTaps, row.count, row.status])
            }
            for row in wird.days {
                try db.execute(sql: """
                    INSERT INTO wirdDay (wirdId, day, state, taps, completedAt, lastActivityAt) VALUES (?, ?, ?, ?, ?, ?)
                    """, arguments: [row.wirdID, row.day, row.state, row.taps, row.completedAt, row.lastActivityAt])
            }
        }
    }
}
