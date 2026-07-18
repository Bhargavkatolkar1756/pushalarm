// PushAlarm — ChallengeResult.swift
// Immutable record of one completed push-up alarm challenge.

import Foundation

struct ChallengeResult: Codable, Identifiable, Equatable {
    let id: UUID
    let alarmId: UUID
    let alarmLabel: String
    let completedAt: Date
    let repsCompleted: Int
    let repsTarget: Int
    let durationSeconds: Double   // wall-clock seconds from challenge start to last rep

    var completionRate: Double {
        guard repsTarget > 0 else { return 0 }
        return Double(repsCompleted) / Double(repsTarget)
    }

    var dateString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: completedAt)
    }

    init(
        id: UUID = UUID(),
        alarmId: UUID,
        alarmLabel: String,
        completedAt: Date = Date(),
        repsCompleted: Int,
        repsTarget: Int,
        durationSeconds: Double
    ) {
        self.id = id
        self.alarmId = alarmId
        self.alarmLabel = alarmLabel
        self.completedAt = completedAt
        self.repsCompleted = repsCompleted
        self.repsTarget = repsTarget
        self.durationSeconds = durationSeconds
    }
}
