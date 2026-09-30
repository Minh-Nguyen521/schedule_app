import SwiftUI

extension Color {
    /// Parses `#RRGGBB`. Falls back to accent colour on malformed input so a
    /// bad stored value can never blank out a row.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = .accentColor
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum HabitPalette {
    static let colors: [String] = [
        "#4F8CFF", "#34C759", "#FF9F0A", "#FF375F",
        "#AF52DE", "#00C7BE", "#FFD60A", "#8E8E93",
    ]

    static let emojis: [String] = [
        "✅", "🏋️", "📚", "🇯🇵", "🧘", "🏃", "💧", "🛏️",
        "🧹", "💻", "🎸", "🥗", "☀️", "✍️", "🧠", "🚭",
    ]
}

enum WeekdayHelper {
    /// Weekday numbers ordered by the user's locale (Monday-first in most of
    /// the world, Sunday-first in the US), so the picker matches the calendar.
    static func ordered(calendar: Calendar = .current) -> [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    static func shortSymbol(_ weekday: Int, calendar: Calendar = .current) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        guard (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }

    static func summary(_ weekdays: [Int], calendar: Calendar = .current) -> String {
        let set = Set(weekdays)
        if set.count == 7 { return "Every day" }
        if set.isEmpty { return "Never" }
        if set == [2, 3, 4, 5, 6] { return "Weekdays" }
        if set == [1, 7] { return "Weekends" }
        return ordered(calendar: calendar)
            .filter { set.contains($0) }
            .map { shortSymbol($0, calendar: calendar) }
            .joined(separator: " ")
    }
}
