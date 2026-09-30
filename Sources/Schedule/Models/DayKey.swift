import Foundation

/// A calendar day identified by its `yyyyMMdd` integer, e.g. `20260930`.
///
/// Habit tracking is about *days*, not instants. Storing a `Date` for "the day I
/// went to the gym" breaks the moment the user crosses a timezone or a DST
/// boundary: the stored instant silently lands on the previous or next day. A
/// day key has no time component to drift, sorts correctly as an integer, and
/// stays stable no matter where the phone is.
nonisolated struct DayKey: Hashable, Comparable, Codable, Sendable {
    /// The `yyyyMMdd` form, e.g. `20260930`.
    let raw: Int

    init(raw: Int) {
        self.raw = raw
    }

    init(year: Int, month: Int, day: Int) {
        self.raw = year * 10_000 + month * 100 + day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    static func today(calendar: Calendar = .current) -> DayKey {
        DayKey(Date(), calendar: calendar)
    }

    var year: Int { raw / 10_000 }
    var month: Int { (raw / 100) % 100 }
    var day: Int { raw % 100 }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.raw < rhs.raw }

    /// Midnight at the start of this day, in `calendar`.
    func startOfDay(in calendar: Calendar = .current) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        // A day key always names a real calendar day, so this resolves; the
        // fallback only exists to keep the API non-optional at call sites.
        return calendar.date(from: c) ?? Date(timeIntervalSince1970: 0)
    }

    /// `Calendar` weekday numbering: 1 = Sunday ... 7 = Saturday.
    func weekday(in calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: startOfDay(in: calendar))
    }

    /// Steps by whole days through the calendar, so DST transitions and
    /// month/year rollover are handled by `Calendar` rather than by arithmetic.
    func adding(days: Int, in calendar: Calendar = .current) -> DayKey {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: startOfDay(in: calendar)) else {
            return self
        }
        return DayKey(shifted, calendar: calendar)
    }

    /// Whole days from `self` to `other`; negative when `other` is earlier.
    func days(until other: DayKey, in calendar: Calendar = .current) -> Int {
        calendar.dateComponents(
            [.day],
            from: startOfDay(in: calendar),
            to: other.startOfDay(in: calendar)
        ).day ?? 0
    }
}

nonisolated extension DayKey: CustomStringConvertible {
    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
