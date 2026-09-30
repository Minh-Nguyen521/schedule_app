import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Habit> { !$0.isArchived },
        sort: [SortDescriptor(\Habit.sortIndex)]
    )
    private var habits: [Habit]

    @State private var selectedDay: DayKey = .today()
    @State private var editingHabit: Habit?
    @State private var isCreating = false
    @State private var showingSettings = false

    private let calendar = Calendar.current
    private var today: DayKey { .today(calendar: calendar) }

    var body: some View {
        List {
            Section {
                WeekStrip(selectedDay: $selectedDay, completion: completion(for:))
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            if habits.isEmpty {
                Section { emptyState }
            } else {
                Section {
                    if scheduled.isEmpty {
                        Text("Nothing scheduled for \(dayLabel.lowercased()).")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(scheduled) { habit in
                        row(habit, isScheduled: true)
                    }
                } header: {
                    header
                }

                if !unscheduled.isEmpty {
                    Section("Other habits") {
                        ForEach(unscheduled) { habit in
                            row(habit, isScheduled: false)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(dayLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New habit")
            }
        }
        .sheet(isPresented: $isCreating) {
            HabitEditView(habit: nil, existingHabits: habits)
        }
        .sheet(item: $editingHabit) { habit in
            HabitEditView(habit: habit, existingHabits: habits)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        // A build left running overnight would otherwise keep yesterday
        // selected and silently tick the wrong day.
        .onChange(of: today) { _, newToday in
            if selectedDay > newToday { selectedDay = newToday }
        }
    }

    private func row(_ habit: Habit, isScheduled: Bool) -> some View {
        let isChecked = habit.isChecked(on: selectedDay)
        return HabitRow(
            habit: habit,
            isChecked: isChecked,
            streak: HabitStore.stats(for: habit, asOf: today, calendar: calendar).currentStreak,
            isScheduled: isScheduled,
            onToggle: { toggle(habit) }
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                HabitStore.delete(habit, context: context)
                NotificationService.shared.cancel(for: habit)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editingHabit = habit
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private var header: some View {
        HStack {
            Text(dayLabel.uppercased())
            Spacer()
            Text("\(completedCount)/\(scheduled.count)")
                .monospacedDigit()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No habits yet", systemImage: "checklist")
        } description: {
            Text("Add the things you want to keep track of. Tap a row each day you do it.")
        } actions: {
            Button("Add a habit") { isCreating = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var scheduled: [Habit] {
        habits.filter { $0.isActive(on: selectedDay, calendar: calendar) }
    }

    private var unscheduled: [Habit] {
        habits.filter { !$0.isActive(on: selectedDay, calendar: calendar) }
    }

    private var completedCount: Int {
        scheduled.count(where: { $0.isChecked(on: selectedDay) })
    }

    private var dayLabel: String {
        if selectedDay == today { return "Today" }
        if selectedDay == today.adding(days: -1, in: calendar) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: selectedDay.startOfDay(in: calendar))
    }

    private func completion(for day: DayKey) -> Double {
        let due = habits.filter { $0.isActive(on: day, calendar: calendar) }
        guard !due.isEmpty else { return 0 }
        return Double(due.count(where: { $0.isChecked(on: day) })) / Double(due.count)
    }

    private func toggle(_ habit: Habit) {
        HabitStore.toggle(habit, on: selectedDay, context: context)
        Haptics.tick(completed: habit.isChecked(on: selectedDay))
    }
}
