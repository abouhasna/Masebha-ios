import Foundation

/// A backup file's content, already validated (format 1, shared with Android in both directions).
nonisolated struct BackupFile: Equatable, Sendable {
    static let format = 1

    /// Ids and positions exactly as in the file.
    var dhikr: [Dhikr]
    /// Android `ColorsPrefs` values (signed 32-bit ARGB) by key. nil = the file has no colors.
    var colors: [String: Int64]?
    /// Android preference values by key, with the type they were stored with.
    var settings: [String: JSONValue]
    /// nil = the file has no wird section: the current wird data is kept.
    var wird: WirdBackup?
}

/// The three wird tables, row by row (Android's columns).
nonisolated struct WirdBackup: Equatable, Sendable {
    struct Wird: Equatable, Sendable {
        var id: Int64
        var name: String
        var position: Int
        var createdAt: Int64
        var lastOpenedAt: Int64
        var deleted: Bool
    }

    struct Item: Equatable, Sendable {
        var id: Int64
        var wirdID: Int64
        var position: Int
        var body: String
        var target: Int
        var timerDelayMs: Int
        var totalTaps: Int
        var count: Int
        var status: Int
    }

    struct Day: Equatable, Sendable {
        var wirdID: Int64
        var day: String
        var state: Int
        var taps: Int
        var completedAt: Int64
        var lastActivityAt: Int64
    }

    var wirds: [Wird]
    var items: [Item]
    var days: [Day]
}

nonisolated enum BackupError: Error, Equatable {
    case tooLarge
    /// Not a JSON object.
    case unreadable
    /// `format` is not 1 (a newer app made it, or it is not a backup).
    case unsupportedFormat
    /// A missing or wrong value; the text says which (for tests and diagnostics).
    case invalid(String)
}

/// Reads and writes backup files (≈ BackupManager on Android, same JSON).
///
/// Reading checks everything before anything is changed: Android's rules (all columns present,
/// loop size > 0, unique ids, no orphan wird rows) plus value ranges. Numbers that Android itself
/// tolerates are normalized the same way (a timer delay under 100 ms means 1 s).
nonisolated enum BackupCodec {
    static let maximumBytes = 8 * 1024 * 1024

    // MARK: Reading

    static func decode(_ data: Data) throws -> BackupFile {
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        guard let root = (try? JSONDecoder().decode(JSONValue.self, from: data))?.object else {
            throw BackupError.unreadable
        }
        guard root["format"]?.int == Int64(BackupFile.format) else { throw BackupError.unsupportedFormat }
        guard let zeker = root["zeker"]?.array else { throw BackupError.invalid("zeker") }

        var ids = Set<Int64>()
        let dhikr = try zeker.map { value -> Dhikr in
            let row = try Fields(value, table: "zeker")
            let id = try row.int64("_id")
            guard ids.insert(id).inserted else { throw BackupError.invalid("zeker: duplicate _id \(id)") }
            let loopSize = try row.int("dawra")
            let total = try row.int("total")
            guard loopSize > 0, total >= 0 else { throw BackupError.invalid("zeker: dawra or total at _id \(id)") }
            let opened = try row.int64("last_opened_at")
            return Dhikr(id: id, name: try row.string("name"), total: total, loopSize: loopSize,
                         position: try row.int("position"),
                         lastOpenedAt: opened > 0 ? Date(timeIntervalSince1970: Double(opened) / 1000) : nil,
                         timerDelayMs: TimerDelay.sanitized(try row.int("timer_delay_ms")))
        }

        var colors: [String: Int64]?
        if let object = root["colors"]?.object {
            var found: [String: Int64] = [:]
            for slot in ColorSlot.allCases {
                if let value = object[slot.rawValue]?.int { found[slot.rawValue] = value }
            }
            colors = found
        }

        var wird: WirdBackup?
        if let section = root["wird"], section != .null {
            wird = try decodeWird(section)
        }
        return BackupFile(dhikr: dhikr, colors: colors, settings: root["settings"]?.object ?? [:], wird: wird)
    }

    private static func decodeWird(_ section: JSONValue) throws -> WirdBackup {
        guard let object = section.object, let wirdRows = object["wirds"]?.array,
              let itemRows = object["items"]?.array, let dayRows = object["days"]?.array else {
            throw BackupError.invalid("wird")
        }

        var wirdIDs = Set<Int64>()
        let wirds = try wirdRows.map { value -> WirdBackup.Wird in
            let row = try Fields(value, table: "wird")
            let id = try row.int64("_id")
            let name = try row.string("name")
            let deleted = try row.int("deleted")
            guard wirdIDs.insert(id).inserted, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  deleted == 0 || deleted == 1 else { throw BackupError.invalid("wird row \(id)") }
            return .init(id: id, name: name, position: try row.int("position"), createdAt: try row.int64("created_at"),
                         lastOpenedAt: try row.int64("last_opened_at"), deleted: deleted == 1)
        }

        var itemIDs = Set<Int64>()
        let items = try itemRows.map { value -> WirdBackup.Item in
            let row = try Fields(value, table: "wird_item")
            let id = try row.int64("_id")
            let wirdID = try row.int64("wird_id")
            let body = try row.string("body")
            let target = try row.int("target")
            let count = try row.int("cnt")
            let status = try row.int("status")
            let totalTaps = try row.int("total_taps")
            guard itemIDs.insert(id).inserted, wirdIDs.contains(wirdID),
                  !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, target > 0, count >= 0,
                  totalTaps >= 0, (0...2).contains(status) else { throw BackupError.invalid("wird_item row \(id)") }
            return .init(id: id, wirdID: wirdID, position: try row.int("position"), body: body, target: target,
                         timerDelayMs: TimerDelay.sanitized(try row.int("timer_delay_ms")), totalTaps: totalTaps,
                         count: count, status: status)
        }

        var dayKeys = Set<String>()
        let days = try dayRows.map { value -> WirdBackup.Day in
            let row = try Fields(value, table: "wird_day")
            let wirdID = try row.int64("wird_id")
            let day = try row.string("day")
            let state = try row.int("state")
            let taps = try row.int("taps")
            guard wirdIDs.contains(wirdID), isDayKey(day), dayKeys.insert("\(wirdID)|\(day)").inserted,
                  (0...2).contains(state), taps >= 0 else { throw BackupError.invalid("wird_day \(wirdID) \(day)") }
            return .init(wirdID: wirdID, day: day, state: state, taps: taps,
                         completedAt: try row.int64("completed_at"), lastActivityAt: try row.int64("last_activity_at"))
        }
        return WirdBackup(wirds: wirds, items: items, days: days)
    }

    /// "yyyy-MM-dd": days are compared as text, so the format must be exact.
    static func isDayKey(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        return parts.count == 3 && parts.map(\.count) == [4, 2, 2]
            && parts.allSatisfy { $0.allSatisfy { $0.isASCII && $0.isNumber } }
    }

    // MARK: Writing

    static func encode(_ file: BackupFile, exportedAt: Date, versionCode: Int) throws -> Data {
        var root: [String: JSONValue] = [
            "format": .int(Int64(BackupFile.format)),
            "versionCode": .int(Int64(versionCode)),
            "exportedAt": .string(timestamp(exportedAt)),
            "zeker": .array(file.dhikr.map { dhikr in
                .object([
                    "_id": .int(dhikr.id),
                    "name": .string(dhikr.name),
                    "total": .int(Int64(dhikr.total)),
                    "dawra": .int(Int64(dhikr.loopSize)),
                    "position": .int(Int64(dhikr.position)),
                    "last_opened_at": .int(dhikr.lastOpenedAt.map(WirdStore.ms) ?? 0),
                    "timer_delay_ms": .int(Int64(dhikr.timerDelayMs)),
                ])
            }),
            "settings": .object(file.settings),
        ]
        if let colors = file.colors {
            root["colors"] = .object(colors.mapValues { .int($0) })
        }
        if let wird = file.wird {
            root["wird"] = .object([
                "wirds": .array(wird.wirds.map { row in
                    .object(["_id": .int(row.id), "name": .string(row.name), "position": .int(Int64(row.position)),
                             "created_at": .int(row.createdAt), "last_opened_at": .int(row.lastOpenedAt),
                             "deleted": .int(row.deleted ? 1 : 0)])
                }),
                "items": .array(wird.items.map { row in
                    .object(["_id": .int(row.id), "wird_id": .int(row.wirdID), "position": .int(Int64(row.position)),
                             "body": .string(row.body), "target": .int(Int64(row.target)),
                             "timer_delay_ms": .int(Int64(row.timerDelayMs)), "total_taps": .int(Int64(row.totalTaps)),
                             "cnt": .int(Int64(row.count)), "status": .int(Int64(row.status))])
                }),
                "days": .array(wird.days.map { row in
                    .object(["wird_id": .int(row.wirdID), "day": .string(row.day), "state": .int(Int64(row.state)),
                             "taps": .int(Int64(row.taps)), "completed_at": .int(row.completedAt),
                             "last_activity_at": .int(row.lastActivityAt)])
                }),
            ])
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(JSONValue.object(root))
    }

    /// "misbaha-backup-20261117-1430.json", the same name as Android's.
    static func fileName(for date: Date) -> String {
        "misbaha-backup-\(format(date, "yyyyMMdd-HHmm", utc: false)).json"
    }

    private static func timestamp(_ date: Date) -> String {
        format(date, "yyyy-MM-dd'T'HH:mm:ss'Z'", utc: true)
    }

    private static func format(_ date: Date, _ pattern: String, utc: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = utc ? TimeZone(identifier: "UTC") : .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

/// Typed access to one row of a backup table; a missing or wrong value makes the file invalid.
private nonisolated struct Fields {
    let values: [String: JSONValue]
    let table: String

    init(_ value: JSONValue, table: String) throws {
        guard let object = value.object else { throw BackupError.invalid("\(table): not an object") }
        values = object
        self.table = table
    }

    func int64(_ key: String) throws -> Int64 {
        guard let value = values[key]?.int else { throw BackupError.invalid("\(table).\(key)") }
        return value
    }

    func int(_ key: String) throws -> Int {
        guard let value = Int(exactly: try int64(key)) else { throw BackupError.invalid("\(table).\(key)") }
        return value
    }

    func string(_ key: String) throws -> String {
        guard let value = values[key]?.string else { throw BackupError.invalid("\(table).\(key)") }
        return value
    }
}
