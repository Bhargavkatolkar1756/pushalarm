// PushAlarm — AlarmScheduler.swift
// Schedules and cancels UNUserNotificationCenter local notifications for each alarm.

import Foundation
import UserNotifications

// MARK: - AlarmScheduler

final class AlarmScheduler {

    static let shared = AlarmScheduler()
    private init() {}

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            DispatchQueue.main.async { completion(granted, error) }
        }
    }

    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - Schedule / Cancel

    /// Cancels all pending notifications for this alarm, then reschedules if enabled.
    func reschedule(_ alarm: Alarm) {
        cancelNotifications(for: alarm.id)
        guard alarm.isEnabled else { return }
        scheduleNotifications(for: alarm)
    }

    func cancelNotifications(for alarmId: UUID) {
        let identifiers = notificationIdentifiers(for: alarmId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Rebuilds all scheduled notifications from the given alarm list.
    func rebuildAll(from alarms: [Alarm]) {
        cancelAll()
        alarms.filter(\.isEnabled).forEach { scheduleNotifications(for: $0) }
    }

    // MARK: - Private Helpers

    private func scheduleNotifications(for alarm: Alarm) {
        let content = makeContent(for: alarm)

        if alarm.repeatDays.isEmpty {
            // One-shot: fire once at the next occurrence of this time.
            let trigger = oneTimeTrigger(hour: alarm.hour, minute: alarm.minute)
            let id = notificationIdentifier(for: alarm.id, weekday: nil)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("[Scheduler] Error scheduling one-shot: \(error)") }
            }
        } else {
            // Repeating: one notification per enabled weekday.
            for day in alarm.repeatDays {
                let trigger = repeatingTrigger(hour: alarm.hour, minute: alarm.minute, weekday: day.calendarWeekday)
                let id = notificationIdentifier(for: alarm.id, weekday: day.rawValue)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error { print("[Scheduler] Error scheduling repeat: \(error)") }
                }
            }
        }
    }

    private func makeContent(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "PushAlarm" : alarm.label
        content.body = "Complete \(alarm.pushUpTarget) push-ups to silence the alarm!"
        let soundName = UNNotificationSoundName(rawValue: "\(alarm.ringtone.fileName).\(alarm.ringtone.fileExtension)")
        content.sound = UNNotificationSound(named: soundName)
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId":    alarm.id.uuidString,
            "pushUps":    alarm.pushUpTarget,
            "ringtone":   alarm.ringtone.rawValue
        ]
        // Category for foreground deep-link
        content.categoryIdentifier = "ALARM_CHALLENGE"
        return content
    }

    private func oneTimeTrigger(hour: Int, minute: Int) -> UNCalendarNotificationTrigger {
        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    }

    private func repeatingTrigger(hour: Int, minute: Int, weekday: Int) -> UNCalendarNotificationTrigger {
        var comps = DateComponents()
        comps.hour    = hour
        comps.minute  = minute
        comps.second  = 0
        comps.weekday = weekday  // 1 = Sunday … 7 = Saturday
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
    }

    // MARK: - Identifier Helpers

    private func notificationIdentifiers(for alarmId: UUID) -> [String] {
        // one-shot
        var ids = [notificationIdentifier(for: alarmId, weekday: nil)]
        // one per weekday (1-7)
        for w in 1...7 { ids.append(notificationIdentifier(for: alarmId, weekday: w)) }
        return ids
    }

    private func notificationIdentifier(for alarmId: UUID, weekday: Int?) -> String {
        let base = "com.pushalarm.notification.\(alarmId.uuidString)"
        if let w = weekday { return "\(base).day\(w)" }
        return base
    }
}

// MARK: - Notification Category Registration

extension AlarmScheduler {
    /// Call once at app launch to register the ALARM_CHALLENGE category.
    func registerNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_CHALLENGE",
            title: "Start Push-Ups",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "ALARM_CHALLENGE",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted (main thread) when a notification tap brings the alarm to the foreground.
    static let didReceiveAlarmNotification = Notification.Name("didReceiveAlarmNotification")
}
