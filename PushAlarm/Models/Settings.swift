// PushAlarm — Settings.swift
// Global app settings model.

import Foundation

// MARK: - DifficultyPreset

enum DifficultyPreset: String, Codable, CaseIterable, Identifiable {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"
    case custom = "Custom"

    var id: String { rawValue }

    var defaultPushUps: Int {
        switch self {
        case .easy:   return 5
        case .medium: return 15
        case .hard:   return 30
        case .custom: return 10   // user overrides per-alarm
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "🟢"
        case .medium: return "🟡"
        case .hard:   return "🔴"
        case .custom: return "⚙️"
        }
    }
}

// MARK: - AppTheme

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case dark  = "Dark"
    case light = "Light"
    case system = "System"

    var id: String { rawValue }
}

// MARK: - Settings

struct AppSettings: Codable, Equatable {
    var difficultyPreset: DifficultyPreset
    var globalRingtone: RingtoneType   // default for new alarms
    var vibrationEnabled: Bool
    var brightnessBoostedDuringChallenge: Bool
    var theme: AppTheme
    var hasCompletedOnboarding: Bool
    var showSkeletonOverlay: Bool       // debug skeleton on ChallengeView
    var streakCount: Int
    var lastCompletionDate: Date?

    static let `default` = AppSettings(
        difficultyPreset: .medium,
        globalRingtone: .siren,
        vibrationEnabled: true,
        brightnessBoostedDuringChallenge: true,
        theme: .dark,
        hasCompletedOnboarding: false,
        showSkeletonOverlay: false,
        streakCount: 0,
        lastCompletionDate: nil
    )
}
