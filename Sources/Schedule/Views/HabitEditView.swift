import SwiftData
import SwiftUI

/// Create or edit a habit. `habit == nil` means create.
struct HabitEditView: View {
    let habit: Habit?
    let existingHabits: [Habit]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    @State private var name = ""
    @State private var emoji = "✅"
    @State private var colorHex = HabitPalette.colors[0]
    @State private var activeWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var reminderEnabled = false
    @State private var reminderDate = Calendar.current.date(
        bySettingHour: 20, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var showingDeleteConfirmation = false
    @State private var notificationsDenied = false

    private let calendar = Calendar.current

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !activeWeekdays.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit name", text: $name)
                        .autocorrectionDisabled()
                    emojiPicker
                    colorPicker
                }

                Section("Days") {
                    weekdayPicker
                    if activeWeekdays.isEmpty {
                        Text("Pick at least one day.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Reminder") {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker(
                            "Time",
                            selection: $reminderDate,
                            displayedComponents: .hourAndMinute
                        )
                        if notificationsDenied {
                            Text("Notifications are turned off for Schedule. Enable them in Settings for reminders to arrive.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if habit != nil {
                    Section {
                        Button("Delete habit", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } footer: {
                        Text("Deleting also removes its tick history.")
                    }
                }
            }
            .preferredColorScheme(theme.colorScheme)
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid)
                }
            }
            .task { load() }
            .onChange(of: reminderEnabled) { _, enabled in
                if enabled { Task { await requestNotifications() } }
            }
            .confirmationDialog(
                "Delete \(name)?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let habit {
                        NotificationService.shared.cancel(for: habit)
                        HabitStore.delete(habit, context: context)
                    }
                    dismiss()
                }
            }
        }
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(HabitPalette.emojis, id: \.self) { candidate in
                    Button {
                        emoji = candidate
                    } label: {
                        Text(candidate)
                            .font(.title3)
                            .frame(width: 34, height: 34)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(emoji == candidate ? Color.accentColor.opacity(0.2) : .clear)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Colour").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(HabitPalette.colors, id: \.self) { candidate in
                    Button {
                        colorHex = candidate
                    } label: {
                        Circle()
                            .fill(Color(hex: candidate))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if colorHex == candidate {
                                    Circle().strokeBorder(.primary, lineWidth: 2).padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour option")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(WeekdayHelper.ordered(calendar: calendar), id: \.self) { weekday in
                let isOn = activeWeekdays.contains(weekday)
                Button {
                    if isOn { activeWeekdays.remove(weekday) } else { activeWeekdays.insert(weekday) }
                } label: {
                    Text(WeekdayHelper.shortSymbol(weekday, calendar: calendar))
                        .font(.subheadline.weight(isOn ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isOn ? Color(hex: colorHex).opacity(0.25) : Color.secondary.opacity(0.1))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private func load() {
        guard let habit else { return }
        name = habit.name
        emoji = habit.emoji
        colorHex = habit.colorHex
        activeWeekdays = Set(habit.activeWeekdays)
        reminderEnabled = habit.reminderEnabled
        reminderDate = calendar.date(
            bySettingHour: habit.reminderHour, minute: habit.reminderMinute, second: 0, of: Date()
        ) ?? reminderDate
    }

    private func save() {
        let components = calendar.dateComponents([.hour, .minute], from: reminderDate)
        let minutes = (components.hour ?? 20) * 60 + (components.minute ?? 0)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: Habit
        if let habit {
            habit.name = trimmedName
            habit.emoji = emoji
            habit.colorHex = colorHex
            habit.activeWeekdays = activeWeekdays.sorted()
            habit.reminderEnabled = reminderEnabled
            habit.reminderMinutes = minutes
            target = habit
        } else {
            target = HabitStore.create(
                name: trimmedName,
                emoji: emoji,
                colorHex: colorHex,
                activeWeekdays: activeWeekdays.sorted(),
                reminderEnabled: reminderEnabled,
                reminderMinutes: minutes,
                existing: existingHabits,
                context: context
            )
        }

        // Reminders are rebuilt from the saved state, so an edited time or a
        // removed weekday can't leave an orphaned notification behind.
        let habits = existingHabits.contains(where: { $0 === target })
            ? existingHabits
            : existingHabits + [target]
        Task { await NotificationService.shared.refreshAll(for: habits) }

        dismiss()
    }

    private func requestNotifications() async {
        let granted = await NotificationService.shared.requestAuthorization()
        notificationsDenied = !granted
    }
}
