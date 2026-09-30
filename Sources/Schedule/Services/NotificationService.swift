import Foundation
import UserNotifications

/// Local daily reminders. No entitlement needed, which is what makes this
/// workable on a free Personal Team — unlike push, App Groups, or iCloud.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Rebuilds every reminder from scratch.
    ///
    /// Called on launch and after any edit. Reconciling individual requests
    /// would mean tracking which ones exist; wiping and re-adding is cheap at
    /// this scale and cannot drift out of sync with the habits.
    func refreshAll(for habits: [Habit]) async {
        guard await authorizationStatus() == .authorized else { return }

        let identifiers = habits.map(\.notificationIdentifier)
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { id in identifiers.contains { id.hasPrefix($0) } || id.hasPrefix("habit-") }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        for habit in habits where habit.reminderEnabled && !habit.isArchived {
            await schedule(habit)
        }
    }

    func cancel(for habit: Habit) {
        // One request per weekday, so cancel the whole family.
        let identifiers = (1...7).map { "\(habit.notificationIdentifier)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// One repeating request per scheduled weekday.
    ///
    /// A single daily trigger would fire on days the habit isn't scheduled,
    /// which trains you to ignore it.
    private func schedule(_ habit: Habit) async {
        let content = UNMutableNotificationContent()
        content.title = "\(habit.emoji) \(habit.name)"
        content.body = "Did you do it today?"
        content.sound = .default

        for weekday in habit.activeWeekdays {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = habit.reminderHour
            components.minute = habit.reminderMinute

            let request = UNNotificationRequest(
                identifier: "\(habit.notificationIdentifier)-\(weekday)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try? await center.add(request)
        }
    }
}
