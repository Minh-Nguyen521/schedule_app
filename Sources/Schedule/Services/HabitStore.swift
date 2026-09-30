import Foundation
import OSLog
import SwiftData

/// Every mutation of habits and ticks goes through here, so the "one tick per
/// habit per day" rule lives in one place.
@MainActor
enum HabitStore {

    /// Ticks or un-ticks `habit` on `day`.
    ///
    /// Deletes *all* rows for that day rather than the first one: SwiftData has
    /// no composite uniqueness constraint across a relationship, so if a
    /// duplicate ever slips in, toggling heals it instead of leaving a ghost
    /// tick behind.
    static func toggle(_ habit: Habit, on day: DayKey, context: ModelContext) {
        let existing = habit.checkIns.filter { $0.dayRaw == day.raw }
        if existing.isEmpty {
            let checkIn = CheckIn(day: day)
            context.insert(checkIn)
            checkIn.habit = habit

            // Backfilling a day earlier than the habit's start means the habit
            // really began then. Without moving the start back, the day would
            // sit outside the measured range and be written off as a bonus.
            if day.raw < habit.startDayRaw {
                habit.startDayRaw = day.raw
            }
        } else {
            existing.forEach(context.delete)
        }
        commit(context)
    }

    static func create(
        name: String,
        emoji: String,
        colorHex: String,
        activeWeekdays: [Int],
        reminderEnabled: Bool,
        reminderMinutes: Int,
        existing: [Habit],
        context: ModelContext
    ) -> Habit {
        let habit = Habit(
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            activeWeekdays: activeWeekdays.sorted(),
            reminderEnabled: reminderEnabled,
            reminderMinutes: reminderMinutes,
            sortIndex: (existing.map(\.sortIndex).max() ?? -1) + 1
        )
        context.insert(habit)
        commit(context)
        return habit
    }

    static func delete(_ habit: Habit, context: ModelContext) {
        context.delete(habit)
        commit(context)
    }

    static func move(_ habits: [Habit], from source: IndexSet, to destination: Int, context: ModelContext) {
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in reordered.enumerated() {
            habit.sortIndex = index
        }
        commit(context)
    }

    static func stats(for habit: Habit, asOf day: DayKey = .today(), calendar: Calendar = .current) -> HabitStats {
        StreakEngine.stats(
            checked: habit.checkedDays,
            activeWeekdays: Set(habit.activeWeekdays),
            from: habit.startDay,
            asOf: day,
            calendar: calendar
        )
    }

    /// SwiftData autosaves, but ticking is the app's whole purpose and the
    /// build can be killed at any time by a lapsed signature — so flush now.
    ///
    /// A failed save is logged, never trapped. A full disk is a real condition
    /// on a real machine, and an app that records habits should not die at the
    /// moment it cannot write one; the tick stays in the context and the next
    /// save may well succeed.
    static func commit(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("Could not save habit changes: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let logger = Logger(subsystem: "com.dedestudio.schedule", category: "HabitStore")
}
