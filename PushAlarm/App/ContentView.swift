// PushAlarm — ContentView.swift
// Root view: routes to Onboarding, the main TabView, or the ChallengeView.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmStore:    AlarmStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var historyStore:  HistoryStore

    /// Set by AppDelegate when a notification is tapped → presents ChallengeView.
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
        // Listen for alarm notification taps
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveAlarmNotification)) { notif in
            guard let idStr = notif.userInfo?["alarmId"] as? String,
                  let id    = UUID(uuidString: idStr),
                  let alarm = alarmStore.alarms.first(where: { $0.id == id }) else { return }
            activeChallenge = alarm
        }
        // Full-screen challenge presented modally (covers TabView + alarm sound)
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
}
