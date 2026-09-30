import SwiftUI

/// One habit on one day.
///
/// The circle ticks, the rest of the row opens history. Splitting the two
/// targets keeps the action you take daily a single tap, without making the
/// history screen a hidden gesture.
struct HabitRow: View {
    let habit: Habit
    let isChecked: Bool
    let streak: Int
    /// False when the habit isn't scheduled on the shown day — still tickable,
    /// but presented as a bonus rather than an obligation.
    let isScheduled: Bool
    let onToggle: () -> Void

    private var tint: Color { Color(hex: habit.colorHex) }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                CheckCircle(isChecked: isChecked, tint: tint)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "Mark \(habit.name) not done" : "Mark \(habit.name) done")
            .accessibilityAddTraits(isChecked ? .isSelected : [])

            NavigationLink(value: habit) {
                HStack(spacing: 12) {
                    Text(habit.emoji)
                        .font(.title3)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.body.weight(.medium))
                            .strikethrough(isChecked, color: .secondary)
                            .foregroundStyle(isChecked ? .secondary : .primary)
                        subtitle
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if !isScheduled {
            Text("Not scheduled · bonus")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if streak > 1 {
            Text("\(streak) day streak")
                .font(.caption)
                .foregroundStyle(tint)
        } else {
            Text(WeekdayHelper.summary(habit.activeWeekdays))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct CheckCircle: View {
    let isChecked: Bool
    let tint: Color
    var diameter: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isChecked ? tint : Color.secondary.opacity(0.35), lineWidth: 2)
            if isChecked {
                Circle().fill(tint)
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isChecked)
    }
}
