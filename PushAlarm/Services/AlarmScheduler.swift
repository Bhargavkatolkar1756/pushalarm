// PushAlarm — AlarmScheduler.swift
// Schedules and cancels UNUserNotificationCenter local notifications for each alarm.
// Implements anti-dismissal burst notifications so the alarm re-triggers every 5 seconds if ignored or swiped away.

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

    /// Immediately fires a retry notification in 1 second if the user swipes away or dismisses the notification.
    func scheduleImmediateRetry(for alarmIdStr: String, pushUps: Int, ringtoneRaw: String, label: String) {
        let content = UNMutableNotificationContent()
        content.title = label.isEmpty ? "🚨 DO YOUR PUSH-UPS!" : "🚨 \(label)"
        content.body = "Alarm cannot be dismissed! Complete \(pushUps) push-ups now!"

        let ringtone = RingtoneType(rawValue: ringtoneRaw) ?? .siren
        let soundName = UNNotificationSoundName(rawValue: "\(ringtone.fileName).\(ringtone.fileExtension)")
        content.sound = UNNotificationSound(named: soundName)
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId":  alarmIdStr,
            "pushUps":  pushUps,
            "ringtone": ringtoneRaw
        ]
        content.categoryIdentifier = "ALARM_CHALLENGE"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "com.pushalarm.retry.\(alarmIdStr).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[Scheduler] Retry scheduling error: \(error)") }
        }
    }

    // MARK: - Private Helpers

    private func scheduleNotifications(for alarm: Alarm) {
        let content = makeContent(for: alarm)

        // Schedule burst notifications spaced 5 seconds apart across the minute (0s, 5s, 10s, 15s, 20s, 25s, 30s, 35s, 40s, 45s, 50s, 55s)
        let burstOffsets = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

        if alarm.repeatDays.isEmpty {
            // One-shot
            for offset in burstOffsets {
                let trigger = oneTimeTrigger(hour: alarm.hour, minute: alarm.minute, secondOffset: offset)
                let id = notificationIdentifier(for: alarm.id, weekday: nil, offset: offset)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error { print("[Scheduler] Error scheduling burst offset \(offset): \(error)") }
                }
            }
        } else {
            // Repeating
            for day in alarm.repeatDays {
                for offset in burstOffsets {
                    let trigger = repeatingTrigger(hour: alarm.hour, minute: alarm.minute, secondOffset: offset, weekday: day.calendarWeekday)
                    let id = notificationIdentifier(for: alarm.id, weekday: day.rawValue, offset: offset)
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error { print("[Scheduler] Error scheduling repeat burst offset \(offset): \(error)") }
                    }
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
            "ringtone":   alarm.ringtone.rawValue,
            "label":      alarm.label
        ]
        content.categoryIdentifier = "ALARM_CHALLENGE"
        return content
    }

    private func oneTimeTrigger(hour: Int, minute: Int, secondOffset: Int) -> UNCalendarNotificationTrigger {
        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute
        comps.second = secondOffset
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    }

    private func repeatingTrigger(hour: Int, minute: Int, secondOffset: Int, weekday: Int) -> UNCalendarNotificationTrigger {
        var comps = DateComponents()
        comps.hour    = hour
        comps.minute  = minute
        comps.second  = secondOffset
        comps.weekday = weekday
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
    }

    // MARK: - Identifier Helpers

    private func notificationIdentifiers(for alarmId: UUID) -> [String] {
        var ids: [String] = []
        let burstOffsets = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
        for offset in burstOffsets {
            ids.append(notificationIdentifier(for: alarmId, weekday: nil, offset: offset))
            for w in 1...7 {
                ids.append(notificationIdentifier(for: alarmId, weekday: w, offset: offset))
            }
        }
        return ids
    }

    private func notificationIdentifier(for alarmId: UUID, weekday: Int?, offset: Int = 0) -> String {
        let base = "com.pushalarm.notification.\(alarmId.uuidString)"
        if let w = weekday { return "\(base).day\(w).off\(offset)" }
        return "\(base).off\(offset)"
    }
}

// MARK: - Notification Category Registration

extension AlarmScheduler {
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
    static let didReceiveAlarmNotification = Notification.Name("didReceiveAlarmNotification")
}
