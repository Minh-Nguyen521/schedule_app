import Foundation

nonisolated struct HabitStats: Equatable, Sendable {
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    /// Ticks on days the habit was actually scheduled for.
    var completedCount: Int = 0
    /// Scheduled days from the habit's start through the as-of day.
    var expectedCount: Int = 0
    /// Ticks on unscheduled days — credit given, but kept out of streak math.
    var bonusCount: Int = 0

    var completionRate: Double {
        expectedCount > 0 ? Double(completedCount) / Double(expectedCount) : 0
    }
}

/// Streak and completion math, kept free of SwiftData so it can be unit tested
/// against hand-built day sets.
nonisolated enum StreakEngine {

    /// Consecutive scheduled days ticked, counting back from `asOf`.
    ///
    /// The as-of day gets grace: an unticked *today* does not end the streak,
    /// because the day isn't over yet. Any earlier unticked scheduled day does.
    static func currentStreak(
        checked: Set<DayKey>,
        activeWeekdays: Set<Int>,
        asOf: DayKey,
        calendar: Calendar = .current
    ) -> Int {
        guard !activeWeekdays.isEmpty, let earliest = checked.min() else { return 0 }

        var streak = 0
        var day = asOf
        while day >= earliest {
            if activeWeekdays.contains(day.weekday(in: calendar)) {
                if checked.contains(day) {
                    streak += 1
                } else if day != asOf {
                    break
                }
            }
            day = day.adding(days: -1, in: calendar)
        }
        return streak
    }

    /// Longest run of consecutive scheduled days ever ticked.
    static func bestStreak(
        checked: Set<DayKey>,
        activeWeekdays: Set<Int>,
        calendar: Calendar = .current
    ) -> Int {
        guard !activeWeekdays.isEmpty else { return 0 }

        let scheduled = checked
            .filter { activeWeekdays.contains($0.weekday(in: calendar)) }
            .sorted()
        guard !scheduled.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for index in 1..<scheduled.count {
            let expectedPrevious = previousScheduledDay(
                before: scheduled[index],
                activeWeekdays: activeWeekdays,
                calendar: calendar
            )
            run = (expectedPrevious == scheduled[index - 1]) ? run + 1 : 1
            best = max(best, run)
        }
        return best
    }

    static func stats(
        checked: Set<DayKey>,
        activeWeekdays: Set<Int>,
        from startDay: DayKey,
        asOf: DayKey,
        calendar: Calendar = .current
    ) -> HabitStats {
        var stats = HabitStats()
        stats.currentStreak = currentStreak(
            checked: checked, activeWeekdays: activeWeekdays, asOf: asOf, calendar: calendar
        )
        stats.bestStreak = bestStreak(
            checked: checked, activeWeekdays: activeWeekdays, calendar: calendar
        )

        for day in scheduledDays(from: startDay, through: asOf, activeWeekdays: activeWeekdays, calendar: calendar) {
            stats.expectedCount += 1
            if checked.contains(day) { stats.completedCount += 1 }
        }
        stats.bonusCount = checked.count(where: {
            !activeWeekdays.contains($0.weekday(in: calendar))
        })
        return stats
    }

    /// Scheduled days in `start...end`, ascending. Empty if `end` precedes `start`.
    static func scheduledDays(
        from start: DayKey,
        through end: DayKey,
        activeWeekdays: Set<Int>,
        calendar: Calendar = .current
    ) -> [DayKey] {
        guard !activeWeekdays.isEmpty, start <= end else { return [] }

        var days: [DayKey] = []
        var day = start
        while day <= end {
            if activeWeekdays.contains(day.weekday(in: calendar)) {
                days.append(day)
            }
            day = day.adding(days: 1, in: calendar)
        }
        return days
    }

    /// The scheduled day immediately before `day`. Always within 7 steps,
    /// since `activeWeekdays` is non-empty.
    static func previousScheduledDay(
        before day: DayKey,
        activeWeekdays: Set<Int>,
        calendar: Calendar = .current
    ) -> DayKey? {
        guard !activeWeekdays.isEmpty else { return nil }

        var candidate = day
        for _ in 0..<7 {
            candidate = candidate.adding(days: -1, in: calendar)
            if activeWeekdays.contains(candidate.weekday(in: calendar)) {
                return candidate
            }
        }
        return nil
    }
}
