import Foundation
import SwiftData
import Testing

@testable import Schedule

/// Returns the *container*, not just its context.
///
/// A `ModelContext` does not keep its container alive, so handing back only
/// `container.mainContext` let the container deallocate the instant the helper
/// returned — and the next SwiftData call trapped, taking the test host with
/// it. Each test holds the container for its own lifetime instead.
/// A throwaway on-disk store per test.
///
/// `isStoredInMemoryOnly` traps inside SwiftData once these models' relationship
/// is exercised, so tests use a real store in the temporary directory and let
/// the OS reclaim it.
@MainActor
private func makeContainer() throws -> ModelContainer {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("schedule-tests-\(UUID().uuidString).store")
    return try ModelContainer(
        for: Habit.self, CheckIn.self,
        configurations: ModelConfiguration(url: url)
    )
}

/// Serialized: Swift Testing runs a suite's tests concurrently by default, and
/// building several `ModelContainer`s for the same schema at once trips a
/// precondition inside SwiftData and takes the test host down with it.
@MainActor
@Suite("Habit store", .serialized)
struct HabitStoreTests {

    @Test("Ticks and un-ticks a day")
    func toggles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "Read")
        context.insert(habit)
        let today = DayKey.today()

        #expect(!habit.isChecked(on: today))
        HabitStore.toggle(habit, on: today, context: context)
        #expect(habit.isChecked(on: today))
        HabitStore.toggle(habit, on: today, context: context)
        #expect(!habit.isChecked(on: today))
        #expect(habit.checkIns.isEmpty)
    }

    @Test("Ticks a past day without disturbing others")
    func ticksPastDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "Read")
        context.insert(habit)
        let today = DayKey.today()
        let threeDaysAgo = today.adding(days: -3)

        HabitStore.toggle(habit, on: today, context: context)
        HabitStore.toggle(habit, on: threeDaysAgo, context: context)

        #expect(habit.isChecked(on: today))
        #expect(habit.isChecked(on: threeDaysAgo))
        #expect(!habit.isChecked(on: today.adding(days: -1)))
        #expect(habit.checkIns.count == 2)
    }

    /// The bug behind "tapping days in the calendar does nothing": a habit
    /// created today started today, so every earlier cell was disabled.
    /// Backfilling now works and carries the start date with it.
    @Test("Backfilling before the start day moves the start day back")
    func backfillMovesStartDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let today = DayKey.today()
        let habit = Habit(name: "Gym", startDay: today)
        context.insert(habit)
        #expect(habit.startDay == today)

        let fiveDaysAgo = today.adding(days: -5)
        HabitStore.toggle(habit, on: fiveDaysAgo, context: context)

        #expect(habit.startDay == fiveDaysAgo)
        // The backfilled day counts as completed, not as an out-of-range bonus.
        let stats = HabitStore.stats(for: habit, asOf: today)
        #expect(stats.completedCount == 1)
        #expect(stats.bonusCount == 0)
        #expect(stats.expectedCount == 6)
    }

    @Test("Ticking a later day leaves the start day alone")
    func laterDayKeepsStartDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let today = DayKey.today()
        let habit = Habit(name: "Gym", startDay: today.adding(days: -10))
        context.insert(habit)

        HabitStore.toggle(habit, on: today, context: context)
        #expect(habit.startDay == today.adding(days: -10))
    }

    @Test("Un-ticking leaves the widened start day in place")
    func untickKeepsStartDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let today = DayKey.today()
        let habit = Habit(name: "Gym", startDay: today)
        context.insert(habit)
        let earlier = today.adding(days: -4)

        HabitStore.toggle(habit, on: earlier, context: context)
        HabitStore.toggle(habit, on: earlier, context: context)

        #expect(!habit.isChecked(on: earlier))
        // The habit demonstrably existed then, so the range stays widened
        // rather than snapping back and rewriting history.
        #expect(habit.startDay == earlier)
    }

    @Test("Heals duplicate ticks for the same day")
    func healsDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "Read")
        context.insert(habit)
        let today = DayKey.today()

        // Two rows for one day, as a bad migration or a race might leave.
        for _ in 0..<2 {
            let checkIn = CheckIn(day: today)
            context.insert(checkIn)
            checkIn.habit = habit
        }
        #expect(habit.checkIns.count == 2)

        HabitStore.toggle(habit, on: today, context: context)
        #expect(habit.checkIns.isEmpty)
        #expect(!habit.isChecked(on: today))
    }

    @Test("Deleting a habit takes its ticks with it")
    func deleteCascades() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "Read")
        context.insert(habit)
        HabitStore.toggle(habit, on: .today(), context: context)

        HabitStore.delete(habit, context: context)
        let remaining = try context.fetch(FetchDescriptor<CheckIn>())
        #expect(remaining.isEmpty)
    }

    @Test("New habits get increasing sort positions")
    func sortIndexIncrements() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var habits: [Habit] = []
        for name in ["A", "B", "C"] {
            habits.append(HabitStore.create(
                name: name, emoji: "✅", colorHex: "#4F8CFF",
                activeWeekdays: [1, 2, 3, 4, 5, 6, 7],
                reminderEnabled: false, reminderMinutes: 1200,
                existing: habits, context: context
            ))
        }
        #expect(habits.map(\.sortIndex) == [0, 1, 2])
    }
}
