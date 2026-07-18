// PushAlarm — PoseCounterService.swift
// On-device push-up rep counter using AVCaptureSession + Apple Vision VNDetectHumanBodyPoseRequest.
// Optimized for front-facing (selfie) camera perspective.

import Foundation
import AVFoundation
import Vision
import Combine

// MARK: - PushUpPhase

enum PushUpPhase: Equatable {
    case idle       // camera open / setting up
    case up         // arms extended high (> 145°)
    case down       // arms bent low (< 125°)
    case completed  // target reps reached
}

// MARK: - PoseCounterService

final class PoseCounterService: NSObject, ObservableObject {

    // MARK: Published State (main thread)
    @Published private(set) var repCount: Int = 0
    @Published private(set) var phase: PushUpPhase = .idle
    @Published private(set) var isBodyVisible: Bool = false
    @Published private(set) var skeletonPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published private(set) var elbowAngleDegrees: Double = 0
    @Published private(set) var sessionRunning: Bool = false

    // MARK: Configuration
    var targetReps: Int = 10
    var onTargetReached: (() -> Void)? = nil

    // MARK: Private — Capture
    private let captureSession = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer

    // MARK: Private — Processing Queue
    private let processingQueue = DispatchQueue(
        label: "com.pushalarm.poseProcessing",
        qos: .userInitiated
    )

    // MARK: Private — Angle & Thresholds (Optimized for Selfie / Front View)
    // In front-view 2D projection, 3D elbow bending appears wider (110°-125° is low push-up position).
    private let downThreshold: Double = 125.0
    private let upThreshold: Double   = 145.0

    // Debounce: 2 consecutive matching frames to trigger state transition
    private let debounceFrameCount: Int = 2
    private var downFrameCount: Int = 0
    private var upFrameCount: Int   = 0
    private var hasBeenDown: Bool   = false

    // Private queue-owned state
    private var internalPhase: PushUpPhase = .idle
    private var internalRepCount: Int = 0

    // MARK: Private — Visibility Watchdog
    private var lastBodySeenAt: Date? = nil
    private var visibilityTimer: Timer? = nil
    private let visibilityTimeout: TimeInterval = 15.0

    // MARK: Private — Challenge Timing
    private var challengeStartedAt: Date? = nil
    var challengeDurationSeconds: Double {
        guard let start = challengeStartedAt else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Init

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }

    // MARK: - Public API

    func setupSession() async {
        await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                self?.configureCaptureSession()
                continuation.resume()
            }
        }
    }

    func startChallenge(targetReps: Int) {
        self.targetReps = targetReps
        reset()
        processingQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
        startVisibilityWatchdog()
        challengeStartedAt = Date()
        DispatchQueue.main.async { [weak self] in
            self?.sessionRunning = true
            self?.phase = .idle
        }
    }

    func stopSession() {
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        DispatchQueue.main.async { [weak self] in
            self?.sessionRunning = false
        }
    }

    func reset() {
        internalPhase = .idle
        internalRepCount = 0
        downFrameCount = 0
        upFrameCount   = 0
        hasBeenDown    = false
        lastBodySeenAt = nil
        challengeStartedAt = nil
        DispatchQueue.main.async { [weak self] in
            self?.repCount = 0
            self?.phase = .idle
            self?.isBodyVisible = false
            self?.skeletonPoints = [:]
            self?.elbowAngleDegrees = 0
        }
    }

    // MARK: - Private — Session Configuration

    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ),
        let input = try? AVCaptureDeviceInput(device: device),
        captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)

        guard captureSession.canAddOutput(output) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(output)

        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        captureSession.commitConfiguration()
    }

    // MARK: - Private — Visibility Watchdog

    private func startVisibilityWatchdog() {
        visibilityTimer?.invalidate()
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let visible: Bool
            if let last = self.lastBodySeenAt {
                visible = Date().timeIntervalSince(last) < self.visibilityTimeout
            } else {
                visible = false
            }
            DispatchQueue.main.async { self.isBodyVisible = visible }
        }
    }

    // MARK: - Private — Elbow Angle

    private func angleDegrees(from a: CGPoint, vertex: CGPoint, to b: CGPoint) -> Double {
        let v1 = CGPoint(x: a.x - vertex.x, y: a.y - vertex.y)
        let v2 = CGPoint(x: b.x - vertex.x, y: b.y - vertex.y)
        let dot  = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        guard mag1 > 1e-6, mag2 > 1e-6 else { return 0 }
        let cosA = max(-1.0, min(1.0, Double(dot) / (Double(mag1) * Double(mag2))))
        return acos(cosA) * (180.0 / .pi)
    }

    // MARK: - Private — Rep State Machine

    private func processAngle(_ angle: Double) {
        if angle < downThreshold {
            downFrameCount += 1
            upFrameCount = 0
            if downFrameCount >= debounceFrameCount {
                transitionPhase(.down)
            }
        } else if angle > upThreshold {
            upFrameCount += 1
            downFrameCount = 0
            if upFrameCount >= debounceFrameCount {
                transitionPhase(.up)
            }
        } else {
            downFrameCount = 0
            upFrameCount   = 0
        }

        DispatchQueue.main.async { [weak self] in
            self?.elbowAngleDegrees = angle
        }
    }

    private func transitionPhase(_ newPhase: PushUpPhase) {
        switch (internalPhase, newPhase) {

        case (_, .down) where internalPhase != .down:
            internalPhase = .down
            hasBeenDown = true
            DispatchQueue.main.async { [weak self] in self?.phase = .down }

        case (_, .up) where internalPhase != .up:
            if hasBeenDown {
                hasBeenDown = false
                downFrameCount = 0
                upFrameCount   = 0
                internalRepCount += 1
                internalPhase = internalRepCount >= targetReps ? .completed : .up
                let snapshot = (internalRepCount, internalPhase, targetReps)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.repCount = snapshot.0
                    self.phase    = snapshot.1
                    if snapshot.0 >= snapshot.2 {
                        self.onTargetReached?()
                    }
                }
            } else if internalPhase == .idle {
                internalPhase = .up
                DispatchQueue.main.async { [weak self] in self?.phase = .up }
            }

        default:
            break
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension PoseCounterService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first else { return }

        // Lower confidence threshold to 0.15 for smooth joint tracking during motion
        let requiredJoints: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder,
            .leftElbow,    .rightElbow,
            .leftWrist,    .rightWrist,
            .nose,         .neck
        ]

        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for joint in requiredJoints {
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.15 else { continue }
            points[joint] = p.location
        }

        let hasLeft  = points[.leftShoulder]  != nil && points[.leftElbow]  != nil && points[.leftWrist]  != nil
        let hasRight = points[.rightShoulder] != nil && points[.rightElbow] != nil && points[.rightWrist] != nil

        guard hasLeft || hasRight else { return }

        lastBodySeenAt = Date()

        var angles: [Double] = []
        if hasLeft, let ls = points[.leftShoulder], let le = points[.leftElbow], let lw = points[.leftWrist] {
            angles.append(angleDegrees(from: ls, vertex: le, to: lw))
        }
        if hasRight, let rs = points[.rightShoulder], let re = points[.rightElbow], let rw = points[.rightWrist] {
            angles.append(angleDegrees(from: rs, vertex: re, to: rw))
        }

        guard !angles.isEmpty else { return }
        let avgAngle = angles.reduce(0, +) / Double(angles.count)

        DispatchQueue.main.async { [weak self] in
            self?.skeletonPoints = points
        }

        processAngle(avgAngle)
    }
}
