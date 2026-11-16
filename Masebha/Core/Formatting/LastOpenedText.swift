import Foundation

/// The "last opened" line on each card (≈ MyAdapter.formatLastOpened on Android).
nonisolated enum LastOpened: Equatable, Sendable {
    case never
    case justNow               // less than 3 minutes ago
    case today(time: String)   // "HH:mm"
    case yesterday(time: String)
    case date(String)          // "yyyy/MM/dd"

    static func describe(_ opened: Date?, now: Date, calendar: Calendar = .current) -> LastOpened {
        guard let opened else { return .never }
        if now.timeIntervalSince(opened) < 3 * 60 { return .justNow }

        let time = format(opened, "HH:mm", calendar: calendar)
        if calendar.isDate(opened, inSameDayAs: now) { return .today(time: time) }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(opened, inSameDayAs: yesterday) {
            return .yesterday(time: time)
        }
        return .date(format(opened, "yyyy/MM/dd", calendar: calendar))
    }

    private static func format(_ date: Date, _ pattern: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")  // ASCII digits, Gregorian
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
