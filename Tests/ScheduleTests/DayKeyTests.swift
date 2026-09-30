import Foundation
import Testing

@testable import Schedule

private func calendar(_ timeZoneID: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneID)!
    return calendar
}

@Suite("DayKey")
struct DayKeyTests {
    let utc = calendar("UTC")

    @Test("Packs and unpacks yyyyMMdd")
    func packing() {
        let day = DayKey(year: 2026, month: 9, day: 30)
        #expect(day.raw == 20_260_930)
        #expect(day.year == 2026)
        #expect(day.month == 9)
        #expect(day.day == 30)
        #expect(day.description == "2026-09-30")
    }

    @Test("Round-trips through Date")
    func dateRoundTrip() {
        let day = DayKey(year: 2026, month: 2, day: 28)
        #expect(DayKey(day.startOfDay(in: utc), calendar: utc) == day)
    }

    @Test("Knows its weekday")
    func weekday() {
        // 1 Jan 2000 was a Saturday; Calendar numbers Saturday as 7.
        #expect(DayKey(year: 2000, month: 1, day: 1).weekday(in: utc) == 7)
        #expect(DayKey(year: 2000, month: 1, day: 2).weekday(in: utc) == 1) // Sunday
    }

    @Test("Steps across month and year boundaries")
    func boundaries() {
        #expect(DayKey(year: 2026, month: 1, day: 31).adding(days: 1, in: utc)
                == DayKey(year: 2026, month: 2, day: 1))
        #expect(DayKey(year: 2026, month: 12, day: 31).adding(days: 1, in: utc)
                == DayKey(year: 2027, month: 1, day: 1))
        #expect(DayKey(year: 2026, month: 3, day: 1).adding(days: -1, in: utc)
                == DayKey(year: 2026, month: 2, day: 28))
        // 2024 was a leap year.
        #expect(DayKey(year: 2024, month: 3, day: 1).adding(days: -1, in: utc)
                == DayKey(year: 2024, month: 2, day: 29))
    }

    @Test("Steps whole days across a DST transition")
    func daylightSaving() {
        // US clocks spring forward on 8 March 2026: that local day is 23h long.
        let newYork = calendar("America/New_York")
        let before = DayKey(year: 2026, month: 3, day: 7)
        #expect(before.adding(days: 1, in: newYork) == DayKey(year: 2026, month: 3, day: 8))
        #expect(before.adding(days: 2, in: newYork) == DayKey(year: 2026, month: 3, day: 9))
        // And back in autumn, when the day is 25h long.
        let autumn = DayKey(year: 2026, month: 11, day: 1)
        #expect(autumn.adding(days: 1, in: newYork) == DayKey(year: 2026, month: 11, day: 2))
    }

    @Test("Counts days between")
    func distance() {
        let start = DayKey(year: 2026, month: 9, day: 28)
        #expect(start.days(until: DayKey(year: 2026, month: 10, day: 5), in: utc) == 7)
        #expect(start.days(until: start, in: utc) == 0)
        #expect(start.days(until: DayKey(year: 2026, month: 9, day: 27), in: utc) == -1)
    }

    @Test("Orders chronologically")
    func ordering() {
        #expect(DayKey(year: 2026, month: 9, day: 9) < DayKey(year: 2026, month: 9, day: 10))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    }
}
