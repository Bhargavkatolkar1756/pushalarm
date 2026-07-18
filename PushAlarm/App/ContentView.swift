// PushAlarm — ContentView.swift
// Root view: routes to Onboarding, the main TabView, or the ChallengeView.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmStore:    AlarmStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var historyStore:  HistoryStore

    @Environment(\.scenePhase) private var scenePhase

    /// Set by AppDelegate or scenePhase when a notification is tapped / alarm is due → presents ChallengeView.
    @State private var activeChallenge: Alarm? = nil

    var body: some View {
        Group {
            if !settingsStore.settings.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                mainTabView
            }
        }
        .animation(.easeInOut(duration: 0.4), value: settingsStore.settings.hasCompletedOnboarding)
        // Listen for alarm notification taps / arrivals
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveAlarmNotification)) { notif in
            guard let userInfo = notif.userInfo,
                  let idStr = userInfo["alarmId"] as? String,
                  let id = UUID(uuidString: idStr) else { return }

            if let alarm = alarmStore.alarms.first(where: { $0.id == id }) {
                activeChallenge = alarm
            } else {
                // Fallback: construct Alarm directly from userInfo payload
                let label = userInfo["label"] as? String ?? "PushAlarm"
                let pushUps = userInfo["pushUps"] as? Int ?? 10
                let ringtoneRaw = userInfo["ringtone"] as? String ?? "siren"
                let ringtone = RingtoneType(rawValue: ringtoneRaw) ?? .siren
                let alarm = Alarm(id: id, label: label, ringtone: ringtone, pushUpTarget: pushUps)
                activeChallenge = alarm
            }
        }
        // Auto-check for active due alarms when app opens or returns to foreground
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                checkForDueAlarms()
            }
        }
        .onAppear {
            checkForDueAlarms()
        }
        // Full-screen challenge presented modally (covers TabView + camera + alarm sound)
        .fullScreenCover(item: $activeChallenge) { alarm in
            ChallengeView(alarm: alarm)
                .environmentObject(historyStore)
                .environmentObject(settingsStore)
        }
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        TabView {
            AlarmListView(pendingChallenge: $activeChallenge, alarmStore: alarmStore)
                .tabItem {
                    Label("Alarms", systemImage: "alarm.fill")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .accentColor(Color.accentColor)
        .preferredColorScheme(.dark)
    }

    // MARK: - Helper

    private func checkForDueAlarms() {
        guard activeChallenge == nil else { return }
        let now = Date()
        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: now)
        let currentMinute = cal.component(.minute, from: now)

        if let dueAlarm = alarmStore.alarms.first(where: { alarm in
            alarm.isEnabled && alarm.hour == currentHour && alarm.minute == currentMinute
        }) {
            activeChallenge = dueAlarm
        }
    }
}
