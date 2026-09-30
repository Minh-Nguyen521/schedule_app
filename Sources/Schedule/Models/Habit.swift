import Foundation
import SwiftData

/// A thing you intend to do on certain days.
///
/// `nonisolated` because the target compiles with MainActor-by-default
/// isolation; SwiftData drives these objects from its own contexts.
@Model
nonisolated final class Habit {
    var name: String = ""
    var emoji: String = "✅"
    var colorHex: String = "#4F8CFF"

    /// `Calendar` weekday numbers (1 = Sunday ... 7 = Saturday) this habit is
    /// expected on. A day outside this set is neither a success nor a miss —
    /// it simply doesn't count, which is what keeps streaks honest for
    /// weekday-only or thrice-weekly habits.
    var activeWeekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]

    var reminderEnabled: Bool = false
    /// Minutes past local midnight, e.g. `20 * 60 + 30` for 20:30.
    var reminderMinutes: Int = 20 * 60

    var sortIndex: Int = 0
    var isArchived: Bool = false

    /// Day the habit was created; completion rates are measured from here so a
    /// habit added today doesn't show up as having missed all of history.
    var startDayRaw: Int = DayKey.today().raw

    @Relationship(deleteRule: .cascade, inverse: \CheckIn.habit)
    var checkIns: [CheckIn] = []

    init(
        name: String,
        emoji: String = "✅",
        colorHex: String = "#4F8CFF",
        activeWeekdays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        reminderEnabled: Bool = false,
        reminderMinutes: Int = 20 * 60,
        sortIndex: Int = 0,
        startDay: DayKey = .today()
    ) {
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.activeWeekdays = activeWeekdays
        self.reminderEnabled = reminderEnabled
        self.reminderMinutes = reminderMinutes
        self.sortIndex = sortIndex
        self.isArchived = false
        self.startDayRaw = startDay.raw
    }

    var startDay: DayKey { DayKey(raw: startDayRaw) }

    /// Stable identifier for notification requests, derived from the model's
    /// persistent id so it survives app relaunches.
    var notificationIdentifier: String {
        "habit-\(persistentModelID.hashValue)"
    }

    func isActive(on day: DayKey, calendar: Calendar = .current) -> Bool {
        activeWeekdays.contains(day.weekday(in: calendar))
    }

    var checkedDays: Set<DayKey> {
        Set(checkIns.map { DayKey(raw: $0.dayRaw) })
    }

    func isChecked(on day: DayKey) -> Bool {
        checkIns.contains { $0.dayRaw == day.raw }
    }

    var reminderHour: Int { reminderMinutes / 60 }
    var reminderMinute: Int { reminderMinutes % 60 }
}

/// One tick: this habit was done on this day.
///
/// At most one row per (habit, day) — enforced by `HabitStore.toggle`, since
/// SwiftData has no composite uniqueness constraint across a relationship.
@Model
nonisolated final class CheckIn {
    var dayRaw: Int = 0
    var createdAt: Date = Date()
    var habit: Habit?

    init(day: DayKey, habit: Habit? = nil, createdAt: Date = Date()) {
        self.dayRaw = day.raw
        self.habit = habit
        self.createdAt = createdAt
    }

    var day: DayKey { DayKey(raw: dayRaw) }
}
