// PushAlarm — PushAlarmApp.swift
// App entry point. Injects environment objects and wires up the notification delegate.

import SwiftUI
import UserNotifications

@main
struct PushAlarmApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Global stores — single source of truth
    @StateObject private var alarmStore    = AlarmStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var historyStore  = HistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmStore)
                .environmentObject(settingsStore)
                .environmentObject(historyStore)
                .preferredColorScheme(preferredScheme(settingsStore.settings.theme))
        }
    }

    private func preferredScheme(_ theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return nil
        }
    }
}

// MARK: - AppDelegate

/// Handles UNUserNotificationCenter delegate callbacks and posts the alarm notification
/// to ContentView via NotificationCenter.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AlarmScheduler.shared.registerNotificationCategories()
        return true
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Present notification as banner+sound even when app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if let idStr = userInfo["alarmId"] as? String {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .didReceiveAlarmNotification,
                    object: nil,
                    userInfo: ["alarmId": idStr]
                )
            }
        }
        completionHandler([.banner, .sound, .badge])
    }

    /// User tapped the notification — extract alarmId and post to ContentView.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let idStr = userInfo["alarmId"] as? String {
            NotificationCenter.default.post(
                name: .didReceiveAlarmNotification,
                object: nil,
                userInfo: ["alarmId": idStr]
            )
        }
        completionHandler()
    }
}
