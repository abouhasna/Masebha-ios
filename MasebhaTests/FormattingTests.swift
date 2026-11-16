import Foundation
import Testing
@testable import Masebha

struct FormattingTests {
    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ text: String, zone: TimeZone = TimeZone(identifier: "UTC")!) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: Numbers

    @Test(arguments: [(0, "0"), (999, "999"), (1000, "1,000"), (1234567, "1,234,567"), (-1200, "-1,200")])
    func groupsWithAsciiDigits(value: Int, expected: String) {
        #expect(NumberText.grouped(value) == expected)
    }

    @Test func arabicIndicDigitsConvertOnlyDigits() {
        #expect(NumberText.arabicIndicDigits("21 جمادى 1448") == "٢١ جمادى ١٤٤٨")
        #expect(NumberText.arabicIndicDigits("abc") == "abc")
    }

    // MARK: Day keys

    @Test func dayKeyUsesTheLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!   // UTC+3
        let lateUTC = date("2026-11-16 22:30:00")                 // already the 17th in Riyadh
        #expect(DayKey.of(lateUTC, calendar: calendar) == "2026-11-17")
        #expect(DayKey.of(lateUTC, calendar: utcCalendar) == "2026-11-16")
    }

    @Test func dayKeyChangesExactlyAtMidnight() {
        #expect(DayKey.of(date("2026-12-31 23:59:59"), calendar: utcCalendar) == "2026-12-31")
        #expect(DayKey.of(date("2027-01-01 00:00:00"), calendar: utcCalendar) == "2027-01-01")
    }

    // MARK: Last opened

    @Test func neverOpened() {
        #expect(LastOpened.describe(nil, now: Date(), calendar: utcCalendar) == .never)
    }

    @Test func justNowIsUnderThreeMinutes() {
        let now = date("2026-11-16 12:00:00")
        #expect(LastOpened.describe(date("2026-11-16 11:57:01"), now: now, calendar: utcCalendar) == .justNow)
        #expect(LastOpened.describe(date("2026-11-16 11:57:00"), now: now, calendar: utcCalendar) == .today(time: "11:57"))
    }

    @Test func todayYesterdayAndOlder() {
        let now = date("2026-11-16 00:30:00")
        #expect(LastOpened.describe(date("2026-11-16 00:05:00"), now: now, calendar: utcCalendar) == .today(time: "00:05"))
        #expect(LastOpened.describe(date("2026-11-15 23:50:00"), now: now, calendar: utcCalendar) == .yesterday(time: "23:50"))
        #expect(LastOpened.describe(date("2026-11-14 23:50:00"), now: now, calendar: utcCalendar) == .date("2026/11/14"))
    }

    @Test func yesterdayAcrossTheYearBoundary() {
        let now = date("2027-01-01 08:00:00")
        #expect(LastOpened.describe(date("2026-12-31 21:15:00"), now: now, calendar: utcCalendar) == .yesterday(time: "21:15"))
    }
}
