import Foundation

/// Layout maths for the month calendar, kept out of the view so the
/// leading-blank and month-length arithmetic can be tested directly.
nonisolated enum MonthGrid {

    /// One entry per grid slot, row-major, seven per row.
    ///
    /// `nil` marks the padding cells before the 1st, so the 1st lands under the
    /// right weekday column for the user's locale.
    static func cells(for month: DayKey, calendar: Calendar = .current) -> [DayKey?] {
        let first = DayKey(year: month.year, month: month.month, day: 1)
        let leading = (first.weekday(in: calendar) - calendar.firstWeekday + 7) % 7

        guard let range = calendar.range(of: .day, in: .month, for: first.startOfDay(in: calendar))
        else { return [] }

        return Array(repeating: nil, count: leading)
            + range.map { DayKey(year: first.year, month: first.month, day: $0) }
    }
}
