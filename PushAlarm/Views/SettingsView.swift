// PushAlarm — SettingsView.swift
// Global preferences: difficulty, ringtone, vibration, brightness, theme,
// skeleton overlay toggle, history/streak summary, and links.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var historyStore: HistoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0D0D0D"), Color(hex: "1A1A2E")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    // MARK: Streak
                    Section {
                        streakBanner
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())

                    // MARK: Difficulty
                    Section("Default Difficulty") {
                        ForEach(DifficultyPreset.allCases) { preset in
                            Button {
                                withAnimation { settingsStore.settings.difficultyPreset = preset }
                            } label: {
                                HStack {
                                    Text(preset.icon + "  " + preset.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(preset.defaultPushUps) push-ups")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    if settingsStore.settings.difficultyPreset == preset {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                            .font(.caption.bold())
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(preset.rawValue) difficulty, \(preset.defaultPushUps) push-ups")
                            .accessibilityValue(settingsStore.settings.difficultyPreset == preset ? "selected" : "")
                        }
                    }

                    // MARK: Default Ringtone
                    Section("Default Ringtone") {
                        ForEach(RingtoneType.allCases) { tone in
                            Button {
                                settingsStore.settings.globalRingtone = tone
                            } label: {
                                HStack {
                                    Image(systemName: tone.systemIconName)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 22)
                                    Text(tone.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button {
                                        AudioService.shared.preview(ringtone: tone)
                                    } label: {
                                        Image(systemName: "play.circle")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Preview \(tone.displayName)")

                                    if settingsStore.settings.globalRingtone == tone {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                            .font(.caption.bold())
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // MARK: Hardware
                    Section("Hardware") {
                        Toggle(isOn: $settingsStore.settings.vibrationEnabled) {
                            Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                        }
                        .tint(.accentColor)

                        Toggle(isOn: $settingsStore.settings.brightnessBoostedDuringChallenge) {
                            Label("Boost Brightness During Challenge", systemImage: "sun.max.fill")
                        }
                        .tint(.accentColor)
                    }

                    // MARK: Appearance
                    Section("Appearance") {
                        Picker("Theme", selection: $settingsStore.settings.theme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle(isOn: $settingsStore.settings.showSkeletonOverlay) {
                            Label("Show Skeleton Overlay", systemImage: "figure.walk")
                        }
                        .tint(.accentColor)
                    }

                    // MARK: History
                    if !historyStore.results.isEmpty {
                        Section("Recent Challenges") {
                            ForEach(historyStore.results.prefix(5)) { result in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(result.alarmLabel)
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(result.dateString)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(result.repsCompleted) reps")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }

                    // MARK: About
                    Section("About") {
                        Link(destination: URL(string: "https://pushalarm.app/privacy")!) {
                            Label("Privacy Policy", systemImage: "lock.shield")
                        }
                        Link(destination: URL(string: "mailto:support@pushalarm.app")!) {
                            Label("Contact Support", systemImage: "envelope")
                        }
                        HStack {
                            Label("Version", systemImage: "info.circle")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(preferredScheme)
        }
    }

    // MARK: - Streak Banner

    private var streakBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                Text("🔥")
                    .font(.system(size: 32))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(historyStore.currentStreak) day streak")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(historyStore.currentStreak == 0
                     ? "Complete today's alarm to start your streak!"
                     : "Keep it up — don't break the chain!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var preferredScheme: ColorScheme? {
        switch settingsStore.settings.theme {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return nil
        }
    }
}
