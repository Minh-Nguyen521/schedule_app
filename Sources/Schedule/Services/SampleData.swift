#if DEBUG
import Foundation
import SwiftData

/// Debug-only fixtures, inserted when the app is launched with
/// `-seedSampleData`. Used for previews and for eyeballing the calendar and
/// streak screens without a fortnight of real tapping.
enum SampleData {

    @MainActor
    static func seedIfRequested(into container: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData") else { return }

        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar.current
        let today = DayKey.today(calendar: calendar)

        // A daily habit ticked for the last 12 days.
        insert(
            Habit(name: "Read", emoji: "📚", colorHex: "#AF52DE",
                  sortIndex: 0,
                  startDay: today.adding(days: -40, in: calendar)),
            checkedOffsets: Array(-12...0),
            into: context, calendar: calendar, today: today
        )

        // Weekdays only, with a miss last week to exercise a broken streak.
        insert(
            Habit(name: "Gym", emoji: "🏋️", colorHex: "#FF9F0A",
                  activeWeekdays: [2, 3, 4, 5, 6],
                  sortIndex: 1,
                  startDay: today.adding(days: -40, in: calendar)),
            checkedOffsets: [-1, -2, -3, -7, -8, -9, -10],
            into: context, calendar: calendar, today: today
        )

        // Nothing ticked yet, with a reminder on.
        insert(
            Habit(name: "Japanese", emoji: "🇯🇵", colorHex: "#34C759",
                  reminderEnabled: true, reminderMinutes: 21 * 60,
                  sortIndex: 2,
                  startDay: today.adding(days: -5, in: calendar)),
            checkedOffsets: [],
            into: context, calendar: calendar, today: today
        )

        try? context.save()
    }

    private static func insert(
        _ habit: Habit,
        checkedOffsets: [Int],
        into context: ModelContext,
        calendar: Calendar,
        today: DayKey
    ) {
        context.insert(habit)
        for offset in checkedOffsets {
            let checkIn = CheckIn(day: today.adding(days: offset, in: calendar))
            context.insert(checkIn)
            checkIn.habit = habit
        }
    }
}
#endif
