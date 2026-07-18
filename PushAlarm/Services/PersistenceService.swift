// PushAlarm — PersistenceService.swift
// JSON-backed alarm store + UserDefaults settings + challenge history.

import Foundation
import Combine

// MARK: - AlarmStore

/// Observable store for all alarms. Persists to <AppSupport>/alarms.json.
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("PushAlarm", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("alarms.json")
    }()

    init() { load() }

    // MARK: CRUD

    func add(_ alarm: Alarm) {
        alarms.append(alarm)
        save()
    }

    func update(_ alarm: Alarm) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx] = alarm
        save()
    }

    func delete(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        save()
    }

    func delete(id: UUID) {
        alarms.removeAll { $0.id == id }
        save()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[idx].isEnabled = enabled
        save()
    }

    // MARK: Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(alarms)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[AlarmStore] save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            alarms = try JSONDecoder().decode([Alarm].self, from: data)
        } catch {
            print("[AlarmStore] load error: \(error)")
        }
    }
}

// MARK: - SettingsStore

/// Observable store for AppSettings. Persists via UserDefaults.
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings = .default {
        didSet { save() }
    }

    private let key = "com.pushalarm.settings"

    init() { load() }

    // MARK: Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else { return }
        settings = decoded
    }
}

// MARK: - HistoryStore

/// Observable store for ChallengeResult history. Persists to <AppSupport>/history.json.
final class HistoryStore: ObservableObject {
    @Published private(set) var results: [ChallengeResult] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("PushAlarm", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("history.json")
    }()

    init() { load() }

    func add(_ result: ChallengeResult) {
        results.insert(result, at: 0)   // newest first
        if results.count > 365 { results = Array(results.prefix(365)) }
        save()
    }

    /// Number of consecutive calendar days with at least one completion.
    var currentStreak: Int {
        var streak = 0
        let cal = Calendar.current
        var checkDate = cal.startOfDay(for: Date())
        for _ in 0..<365 {
            let hasResult = results.contains {
                cal.isDate($0.completedAt, inSameDayAs: checkDate)
            }
            if hasResult {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }

    private func save() {
        if let data = try? JSONEncoder().encode(results) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ChallengeResult].self, from: data) else { return }
        results = decoded
    }
}
