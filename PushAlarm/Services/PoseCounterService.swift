// PushAlarm — PoseCounterService.swift
// On-device push-up rep counter using AVCaptureSession + Apple Vision VNDetectHumanBodyPoseRequest.
// No data leaves the device — all processing is done in-memory on background queues.

import Foundation
import AVFoundation
import Vision
import Combine

// MARK: - PushUpPhase

/// State of the push-up rep state machine.
enum PushUpPhase: Equatable {
    case idle       // not started / camera just opened
    case up         // arms extended (elbow angle > 150°)
    case down       // arms bent low (elbow angle < 90°)
    case completed  // target reps reached
}

// MARK: - PoseCounterService

final class PoseCounterService: NSObject, ObservableObject {

    // MARK: Published State (always updated on main thread)
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
    let previewLayer: AVCaptureVideoPreviewLayer   // exposed so CameraPreviewView can attach it

    // MARK: Private — Processing
    private let processingQueue = DispatchQueue(
        label: "com.pushalarm.poseProcessing",
        qos: .userInitiated
    )

    // MARK: Private — Rep State Machine
    //  Angle thresholds (degrees at the elbow joint):
    //    < DOWN_THRESHOLD  → "down" state
    //    > UP_THRESHOLD    → "up" state (from down → triggers rep)
    private let downThreshold: Double = 90.0
    private let upThreshold: Double   = 155.0

    // Debounce: require this many consecutive matching frames before transitioning state.
    private let debounceFrameCount: Int = 4
    private var downFrameCount: Int  = 0
    private var upFrameCount: Int    = 0
    private var hasBeenDown: Bool    = false   // ensures a full down→up cycle

    // Private phase tracking on the processing queue (avoids reading @Published on bg thread)
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
        captureSession.sessionPreset = .medium

        // Front (selfie) camera only
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

        // Portrait orientation + mirror for selfie view
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

    /// Computes the angle (degrees) at the vertex joint given three 2-D points.
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

    // MARK: - Private — Rep State Machine (called on processing queue)

    private func processAngle(_ angle: Double) {
        // Debounce "down"
        if angle < downThreshold {
            downFrameCount += 1
            upFrameCount = 0
            if downFrameCount >= debounceFrameCount {
                transitionPhase(.down)
            }
        }
        // Debounce "up"
        else if angle > upThreshold {
            upFrameCount += 1
            downFrameCount = 0
            if upFrameCount >= debounceFrameCount {
                transitionPhase(.up)
            }
        }
        // Neutral zone — reset frame counters but keep phase
        else {
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
                // Completed one rep
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
                // Starting position (first "up" before any rep)
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

        // Extract joints with confidence filter
        let requiredJoints: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder,
            .leftElbow,    .rightElbow,
            .leftWrist,    .rightWrist
        ]

        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for joint in requiredJoints {
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.3 else { continue }
            points[joint] = p.location
        }

        // Need at least one complete arm for angle calculation
        let hasLeft  = points[.leftShoulder]  != nil && points[.leftElbow]  != nil && points[.leftWrist]  != nil
        let hasRight = points[.rightShoulder] != nil && points[.rightElbow] != nil && points[.rightWrist] != nil

        guard hasLeft || hasRight else { return }

        // Update visibility timestamp (on processing queue, read by watchdog timer)
        lastBodySeenAt = Date()

        // Calculate elbow angle(s)
        var angles: [Double] = []
        if hasLeft, let ls = points[.leftShoulder], let le = points[.leftElbow], let lw = points[.leftWrist] {
            angles.append(angleDegrees(from: ls, vertex: le, to: lw))
        }
        if hasRight, let rs = points[.rightShoulder], let re = points[.rightElbow], let rw = points[.rightWrist] {
            angles.append(angleDegrees(from: rs, vertex: re, to: rw))
        }
        let avgAngle = angles.reduce(0, +) / Double(angles.count)

        // Publish skeleton for overlay
        DispatchQueue.main.async { [weak self] in
            self?.skeletonPoints = points
        }

        // Feed angle into state machine
        processAngle(avgAngle)
    }
}
