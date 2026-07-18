// PushAlarm — ChallengeViewModel.swift
// Coordinates PoseCounterService + AudioService for the push-up challenge screen.

import Foundation
import AVFoundation
import Vision
import Combine

enum ChallengeState: Equatable {
    case waitingForCamera   // session setting up
    case active             // camera running, counting reps
    case bodyNotVisible     // body not detected for >15 seconds
    case completed          // target reps done 🎉
    case error(String)
}

@MainActor
final class ChallengeViewModel: ObservableObject {

    // MARK: Published
    @Published var state: ChallengeState = .waitingForCamera
    @Published var repCount: Int = 0
    @Published var elbowAngle: Double = 0
    @Published var isBodyVisible: Bool = false
    @Published var phase: PushUpPhase = .idle

    let alarm: Alarm
    let poseService: PoseCounterService
    let audioService: AudioService

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(alarm: Alarm, audioService: AudioService = .shared) {
        self.alarm        = alarm
        self.audioService = audioService
        self.poseService  = PoseCounterService()

        bindPoseService()
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task {
            await poseService.setupSession()
            poseService.targetReps = alarm.pushUpTarget
            poseService.onTargetReached = { [weak self] in
                Task { @MainActor in self?.handleCompletion() }
            }
            poseService.startChallenge(targetReps: alarm.pushUpTarget)
            state = .active
            audioService.play(ringtone: alarm.ringtone)
        }
    }

    func onDisappear() {
        poseService.stopSession()
        audioService.stop()
    }

    // MARK: - Private

    private func bindPoseService() {
        poseService.$repCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$repCount)

        poseService.$phase
            .receive(on: DispatchQueue.main)
            .assign(to: &$phase)

        poseService.$elbowAngleDegrees
            .receive(on: DispatchQueue.main)
            .assign(to: &$elbowAngle)

        poseService.$isBodyVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                guard let self else { return }
                self.isBodyVisible = visible
                if case .active = self.state, !visible {
                    self.state = .bodyNotVisible
                } else if case .bodyNotVisible = self.state, visible {
                    self.state = .active
                }
            }
            .store(in: &cancellables)
    }

    private func handleCompletion() {
        audioService.stop()
        AlarmScheduler.shared.cancelNotifications(for: alarm.id)
        AlarmScheduler.shared.cancelAll()
        state = .completed
        poseService.stopSession()
    }

    // MARK: - Helpers

    var progress: Double {
        guard alarm.pushUpTarget > 0 else { return 0 }
        return min(1.0, Double(repCount) / Double(alarm.pushUpTarget))
    }

    var challengeDuration: Double {
        poseService.challengeDurationSeconds
    }
}
