// PushAlarm — ChallengeView.swift
// Full-screen push-up challenge: camera feed + counter overlay + skeleton + completion screen.

import SwiftUI
import Vision

struct ChallengeView: View {
    @StateObject private var viewModel: ChallengeViewModel
    @EnvironmentObject var historyStore: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var settingsStore: SettingsStore
    @State private var showCompletion: Bool = false
    @State private var particleOpacity: Double = 0

    init(alarm: Alarm) {
        _viewModel = StateObject(wrappedValue: ChallengeViewModel(alarm: alarm))
    }

    var body: some View {
        ZStack {
            // ── Layer 0: Camera Preview ──────────────────────────────────────────
            CameraPreviewView(previewLayer: viewModel.poseService.previewLayer)
                .ignoresSafeArea()

            // ── Layer 1: Dark Vignette ────────────────────────────────────────────
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()

            // ── Layer 2: Skeleton Overlay (optional) ─────────────────────────────
            if settingsStore.settings.showSkeletonOverlay {
                SkeletonOverlayView(joints: viewModel.poseService.skeletonPoints)
                    .ignoresSafeArea()
            }

            // ── Layer 3: UI Overlay ────────────────────────────────────────────────
            VStack(spacing: 0) {
                // Top header
                headerBar

                Spacer()

                // Center counter
                RepCounterView(
                    current: viewModel.repCount,
                    target: viewModel.alarm.pushUpTarget
                )
                .padding(.bottom, 24)

                // Phase indicator
                phaseIndicator

                Spacer()

                // Bottom hint bar
                bottomBar
            }
            .padding(.horizontal, 20)

            // ── Layer 4: Body-Not-Visible Warning ────────────────────────────────
            if case .bodyNotVisible = viewModel.state {
                visibilityWarning
            }

            // ── Layer 5: Completion Screen ────────────────────────────────────────
            if case .completed = viewModel.phase {
                completionOverlay
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.alarm.label)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Get down • Push up • Earn your day")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            // Small progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .padding(.top, 60)
    }

    // MARK: - Phase Indicator

    private var phaseIndicator: some View {
        HStack(spacing: 12) {
            PhaseChip(label: "DOWN", isActive: viewModel.phase == .down, color: .orange)
            PhaseChip(label: "UP",   isActive: viewModel.phase == .up,   color: .green)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Image(systemName: "camera.fill")
                .foregroundColor(.white.opacity(0.4))
                .font(.caption)
            Text("Move back so shoulders & elbows are fully visible")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.leading)
        }
        .padding(.bottom, 40)
        .accessibilityLabel("Camera tip: move back so shoulders and elbows are fully visible")
    }

    // MARK: - Body Not Visible Warning

    private var visibilityWarning: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text("Can't see your body")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("Move back so your shoulders and elbows are in frame.\nThe alarm will keep playing.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
        )
        .padding(32)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Warning: Camera cannot detect your body. Move back so shoulders and elbows are visible.")
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 28) {
                // Pulsing checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 130, height: 130)
                        .scaleEffect(particleOpacity > 0 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                   value: particleOpacity)
                    Circle()
                        .fill(Color.green.opacity(0.35))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark")
                        .font(.system(size: 52, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("You earned it! 💪")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(viewModel.alarm.pushUpTarget) push-ups complete")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Alarm dismissed")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }

                Button {
                    saveResult()
                    dismiss()
                } label: {
                    Text("Start Your Day")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .clipShape(Capsule())
                        .shadow(color: .green.opacity(0.4), radius: 20, y: 8)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                particleOpacity = 1
            }
        }
        .accessibilityLabel("Challenge complete! \(viewModel.alarm.pushUpTarget) push-ups done. Tap Start Your Day to dismiss.")
    }

    // MARK: - Helpers

    private func saveResult() {
        let result = ChallengeResult(
            alarmId: viewModel.alarm.id,
            alarmLabel: viewModel.alarm.label,
            repsCompleted: viewModel.repCount,
            repsTarget: viewModel.alarm.pushUpTarget,
            durationSeconds: viewModel.challengeDuration
        )
        historyStore.add(result)
    }
}

// MARK: - PhaseChip

private struct PhaseChip: View {
    let label: String
    let isActive: Bool
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(isActive ? .black : color.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? color : color.opacity(0.15))
            )
            .animation(.spring(response: 0.25), value: isActive)
            .accessibilityLabel("\(label) phase \(isActive ? "active" : "inactive")")
    }
}

// MARK: - SkeletonOverlayView

/// Draws lines between detected body joints for debugging / user feedback.
struct SkeletonOverlayView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]

    // Bone connections to draw
    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip)
    ]

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let transform: (CGPoint) -> CGPoint = { pt in
                    // Vision uses bottom-left origin; flip Y for UIKit/SwiftUI
                    CGPoint(x: pt.x * size.width, y: (1 - pt.y) * size.height)
                }

                // Bones
                for (a, b) in connections {
                    guard let pa = joints[a], let pb = joints[b] else { continue }
                    var path = Path()
                    path.move(to: transform(pa))
                    path.addLine(to: transform(pb))
                    ctx.stroke(path, with: .color(.green.opacity(0.8)), lineWidth: 2.5)
                }

                // Joints
                for (_, pt) in joints {
                    let p = transform(pt)
                    let rect = CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.accentColor))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
