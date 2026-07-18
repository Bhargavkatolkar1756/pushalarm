// PushAlarm — RepCounterView.swift
// "Rep X / Y" display with an animated circular progress ring.

import SwiftUI

struct RepCounterView: View {
    let current: Int
    let target: Int

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(current) / Double(target))
    }

    // Pulsing scale animation when a new rep is counted
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 10)
                .frame(width: 180, height: 180)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.6)]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: progress)

            // Counter text
            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: current)

                Text("of \(target)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))

                Text(current == 0 ? "reps" : current == 1 ? "rep done" : "reps done")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .scaleEffect(scale)
        .onChange(of: current) { _ in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                scale = 1.12
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6).delay(0.12)) {
                scale = 1.0
            }
        }
        .accessibilityLabel("Rep counter")
        .accessibilityValue("\(current) of \(target) reps completed")
    }
}

#Preview {
    RepCounterView(current: 7, target: 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
