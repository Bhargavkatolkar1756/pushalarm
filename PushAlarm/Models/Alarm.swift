// PushAlarm — Alarm.swift
// Core alarm data model.

import Foundation

// MARK: - WeekDay

enum WeekDay: Int, Codable, CaseIterable, Identifiable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday:    return "Su"
        case .monday:    return "Mo"
        case .tuesday:   return "Tu"
        case .wednesday: return "We"
        case .thursday:  return "Th"
        case .friday:    return "Fr"
        case .saturday:  return "Sa"
        }
    }

    var fullName: String {
        switch self {
        case .sunday:    return "Sunday"
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        }
    }

    /// Maps to the UNCalendarNotificationTrigger weekday component (1 = Sunday … 7 = Saturday).
    var calendarWeekday: Int { rawValue }
}

// MARK: - RingtoneType

enum RingtoneType: String, Codable, CaseIterable, Identifiable {
    case siren           = "Siren"
    case airHorn         = "AirHorn"
    case drillSergeant   = "DrillSergeant"
    case foghorn         = "Foghorn"
    case emergencyBeacon = "EmergencyBeacon"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .siren:           return "Siren"
        case .airHorn:         return "Air Horn"
        case .drillSergeant:   return "Drill Sergeant"
        case .foghorn:         return "Foghorn"
        case .emergencyBeacon: return "Emergency Beacon"
        }
    }

    /// Filename (without extension) expected in the app bundle Resources/Ringtones/.
    var fileName: String { rawValue }

    /// Apple Core Audio Format — best for short-looping iOS sounds.
    var fileExtension: String { "caf" }

    var systemIconName: String {
        switch self {
        case .siren:           return "bolt.fill"
        case .airHorn:         return "horn.fill"
        case .drillSergeant:   return "megaphone.fill"
        case .foghorn:         return "cloud.fog.fill"
        case .emergencyBeacon: return "waveform.path.ecg"
        }
    }
}

// MARK: - Alarm

struct Alarm: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var label: String
    var hour: Int          // 0–23
    var minute: Int        // 0–59
    var repeatDays: Set<WeekDay>
    var isEnabled: Bool
    var ringtone: RingtoneType
    var pushUpTarget: Int  // multiples of 5, 5–100
    var createdAt: Date

    // MARK: Init

    init(
        id: UUID = UUID(),
        label: String = "Wake Up",
        hour: Int = 7,
        minute: Int = 0,
        repeatDays: Set<WeekDay> = [],
        isEnabled: Bool = true,
        ringtone: RingtoneType = .siren,
        pushUpTarget: Int = 10,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
        self.ringtone = ringtone
        self.pushUpTarget = pushUpTarget
        self.createdAt = createdAt
    }

    // MARK: Computed

    /// "7:05 AM" style display string.
    var timeString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let m = String(format: "%02d", minute)
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(ampm)"
    }

    /// Human-readable repeat summary, e.g. "Weekdays", "Every Day", "Mo Tu Fr".
    var repeatSummary: String {
        if repeatDays.isEmpty { return "Once" }
        if repeatDays.count == 7 { return "Every Day" }
        let weekdays: Set<WeekDay> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekend: Set<WeekDay> = [.saturday, .sunday]
        if repeatDays == weekdays { return "Weekdays" }
        if repeatDays == weekend  { return "Weekends" }
        let sorted = repeatDays.sorted { $0.rawValue < $1.rawValue }
        return sorted.map(\.shortName).joined(separator: " ")
    }

    /// Next fire date (nil if disabled or no valid next time).
    func nextFireDate(from now: Date = Date()) -> Date? {
        guard isEnabled else { return nil }
        let cal = Calendar.current
        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0

        if repeatDays.isEmpty {
            // One-shot: next occurrence of this time
            if let d = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) {
                return d
            }
        } else {
            // Repeating: find the earliest next weekday
            var earliest: Date? = nil
            for day in repeatDays {
                comps.weekday = day.calendarWeekday
                if let d = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) {
                    if earliest == nil || d < earliest! { earliest = d }
                }
            }
            return earliest
        }
        return nil
    }
}

// MARK: - Codable for Set<WeekDay>
// Set<WeekDay> is Codable because WeekDay: Codable and Set: Codable when Element: Codable.
// No extra work needed.
