import SwiftData
import SwiftUI

struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.modelContext) private var context
    @State private var displayedMonth: DayKey = .today()
    @State private var isEditing = false

    private let calendar = Calendar.current
    private var today: DayKey { .today(calendar: calendar) }
    private var tint: Color { Color(hex: habit.colorHex) }

    private var stats: HabitStats {
        HabitStore.stats(for: habit, asOf: today, calendar: calendar)
    }

    var body: some View {
        List {
            Section {
                statsRow
            }

            Section {
                monthHeader
                weekdayHeader
                monthGrid
            }

            Section("Details") {
                LabeledContent("Days", value: WeekdayHelper.summary(habit.activeWeekdays, calendar: calendar))
                LabeledContent("Reminder", value: reminderSummary)
                LabeledContent("Started", value: habit.startDay.description)
                if stats.bonusCount > 0 {
                    LabeledContent("Bonus days", value: "\(stats.bonusCount)")
                }
            }
        }
        .navigationTitle("\(habit.emoji) \(habit.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            HabitEditView(habit: habit, existingHabits: [habit])
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statTile("Streak", "\(stats.currentStreak)", "day" + (stats.currentStreak == 1 ? "" : "s"))
            Divider()
            statTile("Best", "\(stats.bestStreak)", "day" + (stats.bestStreak == 1 ? "" : "s"))
            Divider()
            statTile("Done", "\(Int((stats.completionRate * 100).rounded()))%", "\(stats.completedCount)/\(stats.expectedCount)")
        }
        .frame(maxWidth: .infinity)
    }

    private func statTile(_ title: String, _ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous month")

            Spacer()
            Text(monthTitle).font(.headline)
            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next month")
            .disabled(isShowingCurrentMonth)
            .opacity(isShowingCurrentMonth ? 0.3 : 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(WeekdayHelper.ordered(calendar: calendar), id: \.self) { weekday in
                Text(WeekdayHelper.shortSymbol(weekday, calendar: calendar))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dayCell(_ day: DayKey) -> some View {
        let isChecked = habit.isChecked(on: day)
        let isScheduled = habit.isActive(on: day, calendar: calendar)
        let isFuture = day > today

        return Button {
            HabitStore.toggle(habit, on: day, context: context)
            Haptics.tick(completed: habit.isChecked(on: day))
        } label: {
            Text("\(day.day)")
                .font(.system(.footnote, design: .rounded, weight: isChecked ? .bold : .regular))
                .foregroundStyle(cellForeground(isChecked: isChecked, isScheduled: isScheduled))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(isChecked ? tint : (isScheduled ? Color.secondary.opacity(0.1) : .clear))
                }
                .overlay {
                    if day == today {
                        RoundedRectangle(cornerRadius: 9).strokeBorder(tint, lineWidth: 1.5)
                    }
                }
                // Without this the tappable area collapses onto the digits
                // themselves, leaving most of the cell dead to touch.
                .contentShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        // Only the future is off limits. Any past day can be ticked — adding a
        // habit today and recording that you also did it on Monday is normal,
        // and `startDay` moves back to match (see HabitStore.toggle).
        .disabled(isFuture)
        .opacity(isFuture ? 0.25 : 1)
        .accessibilityLabel("\(day.description), \(isChecked ? "done" : "not done")")
    }

    private func cellForeground(isChecked: Bool, isScheduled: Bool) -> Color {
        if isChecked { return .white }
        return isScheduled ? .primary : .secondary
    }

    private var monthCells: [DayKey?] {
        MonthGrid.cells(for: displayedMonth, calendar: calendar)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: displayedMonth.startOfDay(in: calendar))
    }

    private var isShowingCurrentMonth: Bool {
        displayedMonth.year == today.year && displayedMonth.month == today.month
    }

    private var reminderSummary: String {
        guard habit.reminderEnabled else { return "Off" }
        return String(format: "%02d:%02d", habit.reminderHour, habit.reminderMinute)
    }

    private func shiftMonth(by months: Int) {
        guard let shifted = calendar.date(
            byAdding: .month, value: months, to: displayedMonth.startOfDay(in: calendar)
        ) else { return }
        let candidate = DayKey(shifted, calendar: calendar)
        displayedMonth = min(candidate, today)
    }
}
