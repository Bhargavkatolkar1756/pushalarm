// PushAlarm — AlarmListView.swift
// Main alarm list screen with time display, enable toggle, and swipe-to-delete.

import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var settingsStore: SettingsStore
    @StateObject private var viewModel: AlarmListViewModel

    // Presented from ContentView when a notification fires
    @Binding var pendingChallenge: Alarm?

    @State private var showingEditor: Bool = false
    @State private var editingAlarm: Alarm? = nil

    init(pendingChallenge: Binding<Alarm?>, alarmStore: AlarmStore) {
        self._pendingChallenge = pendingChallenge
        self._viewModel = StateObject(wrappedValue: AlarmListViewModel(alarmStore: alarmStore))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "0D0D0D"), Color(hex: "1A1A2E")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if alarmStore.alarms.isEmpty {
                    EmptyAlarmsView { showingEditor = true }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(alarmStore.alarms.sorted {
                                ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute)
                            }) { alarm in
                                AlarmCard(
                                    alarm: alarm,
                                    onToggle: { viewModel.setEnabled($0, for: alarm) },
                                    onTap: {
                                        editingAlarm = alarm
                                        showingEditor = true
                                    },
                                    onDelete: {
                                        if let idx = alarmStore.alarms.firstIndex(where: { $0.id == alarm.id }) {
                                            viewModel.deleteAlarms(at: IndexSet(integer: idx))
                                        }
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .push(from: .trailing),
                                    removal: .push(from: .leading)
                                ))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("PushAlarm")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingAlarm = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Add new alarm")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            AlarmEditorView(
                alarm: editingAlarm,
                defaultPushUps: settingsStore.settings.difficultyPreset.defaultPushUps
            ) { saved in
                if let existing = editingAlarm {
                    var updated = existing
                    updated = saved
                    viewModel.updateAlarm(updated)
                } else {
                    viewModel.addAlarm(saved)
                }
                editingAlarm = nil
                showingEditor = false
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - AlarmCard

private struct AlarmCard: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDeleteButton: Bool = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button (revealed on swipe)
            if showDeleteButton {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 72, height: 96)
                        .background(Color.red.gradient)
                        .cornerRadius(20)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Main card
            HStack(spacing: 16) {
                // Time + label
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.timeString)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(alarm.isEnabled ? .white : .secondary)

                    HStack(spacing: 6) {
                        Text(alarm.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        if !alarm.repeatDays.isEmpty {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(alarm.repeatSummary)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "figure.arms.open")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Text("\(alarm.pushUpTarget) push-ups")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }

                Spacer()

                // Enable toggle
                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .tint(.accentColor)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(alarm.isEnabled
                                    ? Color.accentColor.opacity(0.3)
                                    : Color.white.opacity(0.08),
                                    lineWidth: 1)
                    )
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(-80, value.translation.width)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < -50 {
                                offset = -80
                                showDeleteButton = true
                            } else {
                                offset = 0
                                showDeleteButton = false
                            }
                        }
                    }
            )
            .onTapGesture {
                if showDeleteButton {
                    withAnimation(.spring()) {
                        offset = 0
                        showDeleteButton = false
                    }
                } else {
                    onTap()
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showDeleteButton)
    }
}

// MARK: - EmptyAlarmsView

private struct EmptyAlarmsView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("No Alarms Yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Set your first alarm and\nnever oversleep again — painfully.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                Label("Create Alarm", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(40)
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
