// PushAlarm — AlarmListViewModel.swift
// ViewModel that bridges AlarmStore ↔ AlarmScheduler for the list/editor UIs.

import Foundation
import Combine

@MainActor
final class AlarmListViewModel: ObservableObject {

    @Published var alarms: [Alarm] = []
    @Published var pendingChallengeAlarm: Alarm? = nil
    @Published var notificationsGranted: Bool? = nil

    private let alarmStore: AlarmStore
    private var cancellables = Set<AnyCancellable>()

    init(alarmStore: AlarmStore) {
        self.alarmStore = alarmStore
        // Mirror store's array into our @Published property so SwiftUI views react.
        alarmStore.$alarms
            .receive(on: DispatchQueue.main)
            .assign(to: &$alarms)

        checkNotificationPermission()
    }

    // MARK: - Alarm CRUD

    func addAlarm(_ alarm: Alarm) {
        alarmStore.add(alarm)
        AlarmScheduler.shared.reschedule(alarm)
    }

    func updateAlarm(_ alarm: Alarm) {
        alarmStore.update(alarm)
        AlarmScheduler.shared.reschedule(alarm)
    }

    func deleteAlarms(at offsets: IndexSet) {
        let toDelete = offsets.map { alarms[$0] }
        alarmStore.delete(at: offsets)
        toDelete.forEach { AlarmScheduler.shared.cancelNotifications(for: $0.id) }
    }

    func setEnabled(_ enabled: Bool, for alarm: Alarm) {
        alarmStore.setEnabled(enabled, for: alarm.id)
        var updated = alarm
        updated.isEnabled = enabled
        AlarmScheduler.shared.reschedule(updated)
    }

    // MARK: - Permissions

    func requestNotificationPermission() {
        AlarmScheduler.shared.requestAuthorization { [weak self] granted, _ in
            self?.notificationsGranted = granted
            if granted {
                AlarmScheduler.shared.rebuildAll(from: self?.alarmStore.alarms ?? [])
            }
        }
    }

    func checkNotificationPermission() {
        AlarmScheduler.shared.checkAuthorizationStatus { [weak self] status in
            self?.notificationsGranted = (status == .authorized || status == .provisional)
        }
    }
}
