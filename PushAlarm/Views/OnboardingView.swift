// PushAlarm — OnboardingView.swift
// 3-page first-launch flow: Welcome → Permissions → Calibration push-up.

import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var page: Int = 0
    @State private var cameraGranted: Bool = false
    @State private var notifGranted:  Bool = false
    @State private var showCalibration: Bool = false

    var body: some View {
        ZStack {
            // Full-screen dark background
            Color(hex: "08080F").ignoresSafeArea()

            // Stars / ambient orbs
            ambientBackground

            TabView(selection: $page) {
                welcomePage.tag(0)
                permissionsPage.tag(1)
                calibrationPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.4), value: page)

            // Page dots + navigation buttons at bottom
            VStack {
                Spacer()
                navigationFooter
                    .padding(.bottom, 44)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()
            // App icon badge
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.4), .clear],
                            center: .center, startRadius: 0, endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)
                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, .white],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 16) {
                Text("PushAlarm")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("The alarm you can't snooze.\nYou have to earn silence.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                featurePill(icon: "camera.fill",      text: "Front camera counts your push-ups")
                featurePill(icon: "waveform",         text: "Alarm won't stop until you're done")
                featurePill(icon: "iphone.lock",      text: "100% on-device — no data uploaded")
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Page 1: Permissions

    private var permissionsPage: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 72))
                .foregroundStyle(LinearGradient(
                    colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))

            VStack(spacing: 10) {
                Text("A couple of things")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("PushAlarm needs two permissions to work.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                permissionRow(
                    icon: "bell.badge.fill",
                    title: "Notifications",
                    description: "So your alarm can fire at the right time.",
                    granted: notifGranted
                ) {
                    requestNotificationPermission()
                }
                permissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "To count your push-ups live. Nothing is recorded.",
                    granted: cameraGranted
                ) {
                    requestCameraPermission()
                }
            }

            Text("Camera frames are processed on-device and never stored or transmitted.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Page 2: Calibration

    private var calibrationPage: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "figure.arms.open")
                .font(.system(size: 72))
                .foregroundStyle(LinearGradient(
                    colors: [.green, .teal], startPoint: .top, endPoint: .bottom))

            VStack(spacing: 10) {
                Text("Quick Calibration")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Place your phone on a surface 1–2 metres away, propped up so the front camera can see your upper body.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                calibrationTip(number: "1", text: "Lay phone flat or prop it against something stable")
                calibrationTip(number: "2", text: "Stand so shoulders AND elbows are visible in frame")
                calibrationTip(number: "3", text: "Do one test push-up — the counter should increment")
            }

            Button {
                completeOnboarding()
            } label: {
                Text("I'm Ready — Let's Go!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 16, y: 6)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Navigation Footer

    private var navigationFooter: some View {
        HStack {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.accentColor : Color.white.opacity(0.25))
                        .frame(width: i == page ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: page)
                }
            }

            Spacer()

            if page < 2 {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helper Views

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
    }

    private func permissionRow(
        icon: String, title: String, description: String,
        granted: Bool, action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Allow", action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
        .accessibilityLabel("\(title) permission. \(description). Status: \(granted ? "granted" : "not granted")")
    }

    private func calibrationTip(number: String, text: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -200)
            Circle()
                .fill(Color.purple.opacity(0.10))
                .frame(width: 250)
                .blur(radius: 70)
                .offset(x: 120, y: 250)
        }
    }

    // MARK: - Permissions

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { cameraGranted = granted }
        }
    }

    private func requestNotificationPermission() {
        AlarmScheduler.shared.requestAuthorization { granted, _ in
            DispatchQueue.main.async { notifGranted = granted }
        }
    }

    private func completeOnboarding() {
        settingsStore.settings.hasCompletedOnboarding = true
    }
}
