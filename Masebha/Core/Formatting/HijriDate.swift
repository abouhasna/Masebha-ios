import Foundation

/// The Hijri (Umm al-Qura) date shown in the Azkar screen header.
///
/// Android computes it with java.time's HijrahDate; the unit tests compare this code with
/// Java's output for 16 years of dates. Month names are copied from Java's output, so both apps
/// print exactly the same text.
nonisolated enum HijriDate {
    struct Parts: Equatable, Sendable {
        let year: Int
        let month: Int  // 1...12
        let day: Int
    }

    static let arabicMonthNames = [
        "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
        "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
    ]

    static let englishMonthNames = [
        "Muharram", "Safar", "Rabiʻ I", "Rabiʻ II", "Jumada I", "Jumada II",
        "Rajab", "Shaʻban", "Ramadan", "Shawwal", "Dhuʻl-Qiʻdah", "Dhuʻl-Hijjah",
    ]

    /// Hijri date of `date` (local day), shifted by `offsetDays` (the -2...+2 user setting).
    static func parts(for date: Date, offsetDays: Int = 0, timeZone: TimeZone = .current) -> Parts {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let shifted = gregorian.date(byAdding: .day, value: offsetDays, to: date) ?? date

        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = timeZone
        let components = hijri.dateComponents([.year, .month, .day], from: shifted)
        return Parts(year: components.year ?? 0, month: components.month ?? 1, day: components.day ?? 1)
    }

    /// "21 Jumada I 1448", or "٢١ جمادى الأولى ١٤٤٨" in Arabic.
    static func text(for date: Date, offsetDays: Int, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        let parts = parts(for: date, offsetDays: offsetDays, timeZone: timeZone)
        let monthIndex = min(max(parts.month, 1), 12) - 1
        switch language {
        case .arabic:
            let text = "\(parts.day) \(arabicMonthNames[monthIndex]) \(parts.year)"
            return NumberText.arabicIndicDigits(text)
        case .english:
            return "\(parts.day) \(englishMonthNames[monthIndex]) \(parts.year)"
        }
    }

    /// Weekday name of the (Gregorian) day, e.g. "Sunday" / "الأحد". The offset does not change it,
    /// exactly like the Android app.
    static func weekday(for date: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
