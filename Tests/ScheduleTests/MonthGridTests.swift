import Foundation
import Testing

@testable import Schedule

private func calendar(firstWeekday: Int) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = firstWeekday
    return calendar
}

@Suite("Month grid")
struct MonthGridTests {
    /// 1 September 2026 is a Tuesday; September has 30 days.
    let september = DayKey(year: 2026, month: 9, day: 15)

    @Test("Pads so the 1st lands in the right column, Monday-first")
    func mondayFirst() {
        let cells = MonthGrid.cells(for: september, calendar: calendar(firstWeekday: 2))
        // Monday-first: Tuesday is the second column, so one blank.
        #expect(cells.prefix(1).allSatisfy { $0 == nil })
        #expect(cells[1] == DayKey(year: 2026, month: 9, day: 1))
        #expect(cells.count == 1 + 30)
    }

    @Test("Pads correctly Sunday-first")
    func sundayFirst() {
        let cells = MonthGrid.cells(for: september, calendar: calendar(firstWeekday: 1))
        // Sunday-first: Tuesday is the third column, so two blanks.
        #expect(cells.prefix(2).allSatisfy { $0 == nil })
        #expect(cells[2] == DayKey(year: 2026, month: 9, day: 1))
        #expect(cells.count == 2 + 30)
    }

    @Test("Handles a month starting exactly on the first weekday")
    func noPadding() {
        // 1 June 2026 is a Monday.
        let cells = MonthGrid.cells(for: DayKey(year: 2026, month: 6, day: 1), calendar: calendar(firstWeekday: 2))
        #expect(cells.first == DayKey(year: 2026, month: 6, day: 1))
        #expect(cells.count == 30)
    }

    @Test("Uses the real length of February")
    func februaryLengths() {
        let utc = calendar(firstWeekday: 2)
        let common = MonthGrid.cells(for: DayKey(year: 2026, month: 2, day: 10), calendar: utc)
        let leap = MonthGrid.cells(for: DayKey(year: 2024, month: 2, day: 10), calendar: utc)
        #expect(common.compactMap { $0 }.count == 28)
        #expect(leap.compactMap { $0 }.count == 29)
        #expect(leap.compactMap { $0 }.last == DayKey(year: 2024, month: 2, day: 29))
    }

    @Test("Never leaves a gap between the padding and the 1st")
    func contiguous() {
        for month in 1...12 {
            let cells = MonthGrid.cells(for: DayKey(year: 2026, month: month, day: 1), calendar: calendar(firstWeekday: 2))
            let firstRealIndex = cells.firstIndex { $0 != nil }
            #expect(firstRealIndex != nil)
            #expect(cells[firstRealIndex!] == DayKey(year: 2026, month: month, day: 1))
            #expect(cells[(firstRealIndex! + 1)...].allSatisfy { $0 != nil })
        }
    }
}
