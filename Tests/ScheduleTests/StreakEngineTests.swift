import Foundation
import Testing

@testable import Schedule

/// Fixed timezone so weekday-dependent assertions don't depend on the machine.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private let everyDay: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
private let weekdaysOnly: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri

/// Reference week: 2026-09-28 Mon, 29 Tue, 30 Wed, 10-01 Thu, 02 Fri,
/// 03 Sat, 04 Sun, 05 Mon.
private func day(_ month: Int, _ day: Int) -> DayKey {
    DayKey(year: 2026, month: month, day: day)
}

@Suite("Current streak")
struct CurrentStreakTests {
    @Test("Counts consecutive ticks up to today")
    func consecutive() {
        let checked: Set<DayKey> = [day(9, 28), day(9, 29), day(9, 30)]
        #expect(StreakEngine.currentStreak(
            checked: checked, activeWeekdays: everyDay, asOf: day(9, 30), calendar: utc) == 3)
    }

    @Test("An unticked today does not break the streak")
    func todayIsStillOpen() {
        let checked: Set<DayKey> = [day(9, 28), day(9, 29)]
        #expect(StreakEngine.currentStreak(
            checked: checked, activeWeekdays: everyDay, asOf: day(9, 30), calendar: utc) == 2)
    }

    @Test("An unticked earlier day does break the streak")
    func gapBreaks() {
        // 29th missed, so only the 30th counts.
        let checked: Set<DayKey> = [day(9, 28), day(9, 30)]
        #expect(StreakEngine.currentStreak(
            checked: checked, activeWeekdays: everyDay, asOf: day(9, 30), calendar: utc) == 1)
    }

    @Test("A weekday-only habit skips the weekend rather than breaking")
    func weekendIsNotAMiss() {
        // Fri 2 Oct then Mon 5 Oct, with nothing on Sat/Sun: a streak of 2.
        let checked: Set<DayKey> = [day(10, 2), day(10, 5)]
        #expect(StreakEngine.currentStreak(
            checked: checked, activeWeekdays: weekdaysOnly, asOf: day(10, 5), calendar: utc) == 2)
    }

    @Test("Unscheduled days never count toward the streak")
    func bonusDaysIgnored() {
        // Sat 3 Oct is not scheduled, so it cannot bridge Fri to Mon... it is
        // simply skipped, and Fri + Mon remain consecutive scheduled days.
        let checked: Set<DayKey> = [day(10, 2), day(10, 3), day(10, 5)]
        #expect(StreakEngine.currentStreak(
            checked: checked, activeWeekdays: weekdaysOnly, asOf: day(10, 5), calendar: utc) == 2)
    }

    @Test("No ticks means no streak")
    func empty() {
        #expect(StreakEngine.currentStreak(
            checked: [], activeWeekdays: everyDay, asOf: day(9, 30), calendar: utc) == 0)
    }

    @Test("A habit scheduled on no days has no streak")
    func noScheduledDays() {
        #expect(StreakEngine.currentStreak(
            checked: [day(9, 30)], activeWeekdays: [], asOf: day(9, 30), calendar: utc) == 0)
    }

    @Test("A streak that ended in the past does not count as current")
    func staleStreak() {
        let checked: Set<DayKey> = [day(9, 1), day(9, 2), day(9, 3)]
        #expect(StreakEngine.currentStreak(
            checked: checked, activeWeekdays: everyDay, asOf: day(9, 30), calendar: utc) == 0)
    }

    @Test("Spans a month boundary")
    func acrossMonths() {
        let checked: Set<DayKey> = [day(9, 29), day(9, 30), day(10, 1)]
        #expect(StreakEngine.currentStreak(
            checked: checked, activeWeekdays: everyDay, asOf: day(10, 1), calendar: utc) == 3)
    }
}

@Suite("Best streak")
struct BestStreakTests {
    @Test("Finds the longest historical run")
    func longestRun() {
        // 1-4 Sep is a run of 4; 20-21 Sep is a run of 2.
        let checked: Set<DayKey> = [
            day(9, 1), day(9, 2), day(9, 3), day(9, 4),
            day(9, 20), day(9, 21),
        ]
        #expect(StreakEngine.bestStreak(
            checked: checked, activeWeekdays: everyDay, calendar: utc) == 4)
    }

    @Test("Honours the habit's schedule when measuring runs")
    func scheduledRuns() {
        // Mon 28, Tue 29, Wed 30, Thu 1, Fri 2, Mon 5 — six scheduled days in a row.
        let checked: Set<DayKey> = [
            day(9, 28), day(9, 29), day(9, 30), day(10, 1), day(10, 2), day(10, 5),
        ]
        #expect(StreakEngine.bestStreak(
            checked: checked, activeWeekdays: weekdaysOnly, calendar: utc) == 6)
    }

    @Test("A single tick is a streak of one")
    func single() {
        #expect(StreakEngine.bestStreak(
            checked: [day(9, 30)], activeWeekdays: everyDay, calendar: utc) == 1)
        #expect(StreakEngine.bestStreak(
            checked: [], activeWeekdays: everyDay, calendar: utc) == 0)
    }
}

@Suite("Stats")
struct StatsTests {
    @Test("Measures completion from the habit's start day")
    func completionRate() {
        // Mon 28 - Wed 30 inclusive is 3 scheduled days, 2 ticked.
        let stats = StreakEngine.stats(
            checked: [day(9, 28), day(9, 30)],
            activeWeekdays: everyDay,
            from: day(9, 28),
            asOf: day(9, 30),
            calendar: utc
        )
        #expect(stats.expectedCount == 3)
        #expect(stats.completedCount == 2)
        #expect(abs(stats.completionRate - 2.0 / 3.0) < 0.0001)
    }

    @Test("A habit created today is not retroactively behind")
    func createdToday() {
        let stats = StreakEngine.stats(
            checked: [],
            activeWeekdays: everyDay,
            from: day(9, 30),
            asOf: day(9, 30),
            calendar: utc
        )
        #expect(stats.expectedCount == 1)
        #expect(stats.completedCount == 0)
        #expect(stats.completionRate == 0)
    }

    @Test("Credits unscheduled ticks separately")
    func bonus() {
        // Sat 3 Oct is outside a Mon-Fri schedule.
        let stats = StreakEngine.stats(
            checked: [day(10, 2), day(10, 3)],
            activeWeekdays: weekdaysOnly,
            from: day(10, 2),
            asOf: day(10, 5),
            calendar: utc
        )
        #expect(stats.bonusCount == 1)
        #expect(stats.completedCount == 1)     // Fri only
        #expect(stats.expectedCount == 2)      // Fri 2 and Mon 5
    }

    @Test("Counts only scheduled days in a range")
    func scheduledDaysInRange() {
        let days = StreakEngine.scheduledDays(
            from: day(9, 28), through: day(10, 5), activeWeekdays: weekdaysOnly, calendar: utc)
        #expect(days.count == 6) // Mon-Fri plus the following Monday
        #expect(days.first == day(9, 28))
        #expect(days.last == day(10, 5))
        // An inverted range yields nothing rather than looping.
        #expect(StreakEngine.scheduledDays(
            from: day(10, 5), through: day(9, 28), activeWeekdays: weekdaysOnly, calendar: utc).isEmpty)
    }
}
