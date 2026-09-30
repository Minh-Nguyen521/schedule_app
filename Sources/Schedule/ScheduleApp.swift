import SwiftData
import SwiftUI

@main
struct ScheduleApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Habit.self, CheckIn.self)
        } catch {
            // Nothing sensible to fall back to: without a store there is no app.
            fatalError("Could not open the habit store: \(error)")
        }

        #if DEBUG
        SampleData.seedIfRequested(into: container)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    var body: some View {
        NavigationStack {
            TodayView()
                .navigationDestination(for: Habit.self) { habit in
                    HabitDetailView(habit: habit)
                }
        }
        .preferredColorScheme(theme.colorScheme)
        // Reminders are rebuilt on every foreground: iOS drops pending requests
        // when the app is reinstalled, which for this app happens weekly.
        .task { await NotificationService.shared.refreshAll(for: habits) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await NotificationService.shared.refreshAll(for: habits) }
            }
        }
    }
}
