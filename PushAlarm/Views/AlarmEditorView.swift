// PushAlarm — AlarmEditorView.swift
// Form for creating/editing an alarm: time, label, repeat days, ringtone, push-up target.

import SwiftUI

struct AlarmEditorView: View {
    // nil = new alarm, non-nil = editing existing
    private let existing: Alarm?
    private let defaultPushUps: Int
    private let onSave: (Alarm) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var label: String
    @State private var selectedTime: Date
    @State private var repeatDays: Set<WeekDay>
    @State private var ringtone: RingtoneType
    @State private var pushUpTarget: Int
    @State private var isPreviewing: Bool = false

    init(alarm: Alarm?, defaultPushUps: Int, onSave: @escaping (Alarm) -> Void) {
        self.existing       = alarm
        self.defaultPushUps = defaultPushUps
        self.onSave         = onSave

        if let a = alarm {
            _label          = State(initialValue: a.label)
            _selectedTime   = State(initialValue: Self.dateFrom(hour: a.hour, minute: a.minute))
            _repeatDays     = State(initialValue: a.repeatDays)
            _ringtone       = State(initialValue: a.ringtone)
            _pushUpTarget   = State(initialValue: a.pushUpTarget)
        } else {
            _label          = State(initialValue: "Wake Up")
            _selectedTime   = State(initialValue: Date())
            _repeatDays     = State(initialValue: [])
            _ringtone       = State(initialValue: .siren)
            _pushUpTarget   = State(initialValue: defaultPushUps)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Large time picker
                        timePicker

                        // Form sections
                        VStack(spacing: 16) {
                            // Label
                            editorSection(title: "LABEL") {
                                TextField("e.g. Morning Grind", text: $label)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.07))
                                    .cornerRadius(12)
                            }

                            // Repeat days
                            editorSection(title: "REPEAT") {
                                DayToggleView(selectedDays: $repeatDays)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Push-up count
                            editorSection(title: "PUSH-UP TARGET") {
                                pushUpStepper
                            }

                            // Ringtone
                            editorSection(title: "RINGTONE") {
                                ringtonePicker
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Sub-views

    private var timePicker: some View {
        DatePicker(
            "Alarm Time",
            selection: $selectedTime,
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .colorScheme(.dark)
    }

    private var pushUpStepper: some View {
        HStack {
            Button {
                if pushUpTarget > 5 { pushUpTarget -= 5 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(pushUpTarget > 5 ? .accentColor : .secondary)
            }
            .disabled(pushUpTarget <= 5)
            .accessibilityLabel("Decrease push-up target")

            Spacer()

            VStack(spacing: 2) {
                Text("\(pushUpTarget)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: pushUpTarget)
                Text("push-ups")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                if pushUpTarget < 100 { pushUpTarget += 5 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(pushUpTarget < 100 ? .accentColor : .secondary)
            }
            .disabled(pushUpTarget >= 100)
            .accessibilityLabel("Increase push-up target")
        }
        .padding(.horizontal, 8)
    }

    private var ringtonePicker: some View {
        VStack(spacing: 8) {
            ForEach(RingtoneType.allCases) { tone in
                Button {
                    ringtone = tone
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: tone.systemIconName)
                            .font(.system(size: 18))
                            .foregroundColor(ringtone == tone ? .black : .accentColor)
                            .frame(width: 24)

                        Text(tone.displayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ringtone == tone ? .black : .white)

                        Spacer()

                        if ringtone == tone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                        }

                        // Preview button
                        Button {
                            AudioService.shared.preview(ringtone: tone)
                        } label: {
                            Image(systemName: "play.circle")
                                .font(.system(size: 20))
                                .foregroundColor(ringtone == tone ? .black : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Preview \(tone.displayName)")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ringtone == tone ? Color.accentColor : Color.white.opacity(0.07))
                    )
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: ringtone)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func editorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .kerning(1.5)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func dateFrom(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func save() {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: selectedTime)
        var alarm = existing ?? Alarm()
        alarm.label        = label.isEmpty ? "Alarm" : label
        alarm.hour         = comps.hour ?? 7
        alarm.minute       = comps.minute ?? 0
        alarm.repeatDays   = repeatDays
        alarm.ringtone     = ringtone
        alarm.pushUpTarget = pushUpTarget
        alarm.isEnabled    = true
        onSave(alarm)
    }
}
