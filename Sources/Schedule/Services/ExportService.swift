import Foundation

/// JSON backup of every habit and tick.
///
/// The app's data survives the weekly re-install (same bundle id and team keeps
/// the container), but a signing change or a wiped device does not — so there
/// needs to be a way to get the history out.
enum ExportService {

    struct Export: Codable {
        struct HabitExport: Codable {
            var name: String
            var emoji: String
            var colorHex: String
            var activeWeekdays: [Int]
            var startDay: Int
            var checkedDays: [Int]
        }

        var version = 1
        var exportedAt: Date
        var habits: [HabitExport]
    }

    static func makeJSON(habits: [Habit], now: Date = Date()) throws -> Data {
        let export = Export(
            exportedAt: now,
            habits: habits.map { habit in
                Export.HabitExport(
                    name: habit.name,
                    emoji: habit.emoji,
                    colorHex: habit.colorHex,
                    activeWeekdays: habit.activeWeekdays.sorted(),
                    startDay: habit.startDayRaw,
                    checkedDays: habit.checkIns.map(\.dayRaw).sorted()
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    /// Writes the backup to a temporary file for sharing. Returns the URL.
    static func writeTemporaryFile(habits: [Habit], now: Date = Date()) throws -> URL {
        let data = try makeJSON(habits: habits, now: now)
        let name = "schedule-backup-\(DayKey(now).raw).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
