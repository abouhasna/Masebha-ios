import Foundation
import Testing
@testable import Masebha

private final class BundleToken {}

/// The Hijri date must match what the Android app shows. The fixture was produced by
/// java.time.chrono.HijrahDate (the calendar Android uses) for every 3rd day of 2020–2035.
struct HijriDateTests {
    private let utc = TimeZone(identifier: "UTC")!

    private struct Row {
        let gregorian: Date
        let text: String
        let expected: HijriDate.Parts
    }

    private func fixture() throws -> [Row] {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "hijri_java", withExtension: "tsv"))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utc
        formatter.dateFormat = "yyyy-MM-dd"
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .filter { !$0.hasPrefix("#") }
            .map { line in
                let fields = line.split(separator: "\t").map(String.init)
                let noon = try #require(formatter.date(from: fields[0])).addingTimeInterval(12 * 3600)
                return Row(gregorian: noon, text: fields[0],
                           expected: HijriDate.Parts(year: Int(fields[1])!, month: Int(fields[2])!, day: Int(fields[3])!))
            }
    }

    @Test func matchesJavaForSixteenYears() throws {
        let rows = try fixture()
        #expect(rows.count > 1900)
        var mismatches: [String] = []
        for row in rows {
            let parts = HijriDate.parts(for: row.gregorian, timeZone: utc)
            if parts != row.expected {
                mismatches.append("\(row.text): iOS \(parts) vs Java \(row.expected)")
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches, first: \(mismatches.prefix(5))")
    }

    @Test func theOwnersScreenshotDate() throws {
        // 1 Nov 2026 (a Sunday) shows "الأحد / ٢١ جمادى الأولى ١٤٤٨" on Android.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utc
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let date = try #require(formatter.date(from: "2026-11-01 12:00"))
        #expect(HijriDate.text(for: date, offsetDays: 0, language: .arabic, timeZone: utc) == "٢١ جمادى الأولى ١٤٤٨")
        #expect(HijriDate.text(for: date, offsetDays: 0, language: .english, timeZone: utc) == "21 Jumada I 1448")
        #expect(HijriDate.weekday(for: date, language: .arabic, timeZone: utc) == "الأحد")
        #expect(HijriDate.weekday(for: date, language: .english, timeZone: utc) == "Sunday")
    }

    @Test(arguments: [-2, -1, 1, 2])
    func offsetShiftsByWholeDays(offset: Int) throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utc
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let date = try #require(formatter.date(from: "2026-11-01 12:00"))
        let shiftedDate = date.addingTimeInterval(Double(offset) * 86_400)
        #expect(HijriDate.parts(for: date, offsetDays: offset, timeZone: utc) == HijriDate.parts(for: shiftedDate, timeZone: utc))
    }

    @Test func monthNamesCoverAllTwelveMonths() {
        #expect(HijriDate.arabicMonthNames.count == 12)
        #expect(HijriDate.englishMonthNames.count == 12)
    }
}
