import SwiftUI

/// A swipeable week of day pills. Lets you tick a day you forgot without
/// leaving the main screen, which is the single most common correction.
struct WeekStrip: View {
    @Binding var selectedDay: DayKey
    /// Fraction of that day's scheduled habits already ticked, 0...1.
    let completion: (DayKey) -> Double

    private let calendar = Calendar.current
    private var today: DayKey { .today(calendar: calendar) }

    var body: some View {
        VStack(spacing: 10) {
            header
            HStack(spacing: 6) {
                ForEach(weekDays, id: \.raw) { day in
                    dayPill(day)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous week")

            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()

            Button {
                shiftWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next week")
            .disabled(weekDays.contains { $0 >= today })
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func dayPill(_ day: DayKey) -> some View {
        let isSelected = day == selectedDay
        let isFuture = day > today
        let progress = isFuture ? 0 : completion(day)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 6) {
                Text(WeekdayHelper.shortSymbol(day.weekday(in: calendar), calendar: calendar))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ZStack {
                    Circle()
                        .strokeBorder(.quaternary, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(day.day)")
                        .font(.system(.subheadline, design: .rounded, weight: isSelected ? .bold : .regular))
                }
                .frame(width: 34, height: 34)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : .clear)
            }
            .overlay(alignment: .bottom) {
                if day == today {
                    Circle().fill(Color.accentColor).frame(width: 4, height: 4).padding(.bottom, 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.35 : 1)
    }

    /// The seven days of `selectedDay`'s week, starting on the locale's first weekday.
    private var weekDays: [DayKey] {
        let weekday = selectedDay.weekday(in: calendar)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let start = selectedDay.adding(days: -offset, in: calendar)
        return (0..<7).map { start.adding(days: $0, in: calendar) }
    }

    private var monthTitle: String {
        let first = weekDays.first ?? selectedDay
        let last = weekDays.last ?? selectedDay
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = first.year == last.year && first.month == last.month
            ? "MMMM yyyy" : "MMM yyyy"
        return formatter.string(from: first.startOfDay(in: calendar))
    }

    private func shiftWeek(by weeks: Int) {
        let candidate = selectedDay.adding(days: weeks * 7, in: calendar)
        selectedDay = min(candidate, today)
    }
}
