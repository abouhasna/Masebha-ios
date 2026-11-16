import Foundation

/// The key of a calendar day in the phone's local time zone, e.g. "2026-11-16".
/// Daily statistics are stored per day key. The day changes at local midnight.
nonisolated enum DayKey {
    static func of(_ date: Date, calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func today() -> String {
        of(Date())
    }
}
