// PushAlarm — DayToggleView.swift
// Mon-Sun day-selector for the alarm editor.

import SwiftUI

struct DayToggleView: View {
    @Binding var selectedDays: Set<WeekDay>

    // Display order: Mon → Sun
    private let days: [WeekDay] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days) { day in
                DayChip(
                    label: day.shortName,
                    isSelected: selectedDays.contains(day)
                ) {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }
                .accessibilityLabel(day.fullName)
                .accessibilityValue(selectedDays.contains(day) ? "selected" : "not selected")
            }
        }
    }
}

// MARK: - DayChip

private struct DayChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .black : .secondary)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(uiColor: .systemGray5))
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    DayToggleView(selectedDays: .constant([.monday, .wednesday, .friday]))
        .padding()
        .preferredColorScheme(.dark)
}
