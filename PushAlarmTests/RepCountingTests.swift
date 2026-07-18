// PushAlarm — RepCountingTests.swift
// Unit tests for the PoseCounterService angle calculation and rep-state-machine logic.
// These tests feed synthetic elbow-angle sequences directly into the private state machine
// by exercising a testable subclass / extracted logic. Since processAngle() is on the
// processing queue, we expose a thin synchronous test harness below.

import XCTest
@testable import PushAlarm

// MARK: - Angle Calculation Tests

final class AngleCalculationTests: XCTestCase {

    // Helper that computes the angle at `vertex` between points `a` and `b`.
    private func angleAt(a: CGPoint, vertex: CGPoint, b: CGPoint) -> Double {
        let v1 = CGPoint(x: a.x - vertex.x, y: a.y - vertex.y)
        let v2 = CGPoint(x: b.x - vertex.x, y: b.y - vertex.y)
        let dot  = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        guard mag1 > 1e-6, mag2 > 1e-6 else { return 0 }
        let cosA = max(-1.0, min(1.0, Double(dot) / (Double(mag1) * Double(mag2))))
        return acos(cosA) * (180.0 / .pi)
    }

    func testStraightArmAngle_isApproximately180() {
        // Arm fully extended: shoulder above elbow, wrist below elbow (same horizontal line)
        let shoulder = CGPoint(x: 0.5, y: 0.8)
        let elbow    = CGPoint(x: 0.5, y: 0.5)
        let wrist    = CGPoint(x: 0.5, y: 0.2)
        let angle = angleAt(a: shoulder, vertex: elbow, b: wrist)
        XCTAssertEqual(angle, 180.0, accuracy: 1.0, "Straight arm should be ~180°")
    }

    func testRightAngleElbow_isApproximately90() {
        // Elbow bent to 90°
        let shoulder = CGPoint(x: 0.0, y: 0.5)   // to the left
        let elbow    = CGPoint(x: 0.5, y: 0.5)   // center
        let wrist    = CGPoint(x: 0.5, y: 0.0)   // straight down
        let angle = angleAt(a: shoulder, vertex: elbow, b: wrist)
        XCTAssertEqual(angle, 90.0, accuracy: 1.0, "Right-angle elbow should be ~90°")
    }

    func testAcuteElbow_isBelowDownThreshold() {
        // Arm very bent (push-up low position)
        let shoulder = CGPoint(x: 0.3, y: 0.8)
        let elbow    = CGPoint(x: 0.5, y: 0.5)
        let wrist    = CGPoint(x: 0.7, y: 0.8)
        let angle = angleAt(a: shoulder, vertex: elbow, b: wrist)
        XCTAssertLessThan(angle, 90.0, "Bent arm should be < 90° (below DOWN threshold)")
    }

    func testObtuseElbow_isAboveUpThreshold() {
        // Arms nearly extended (push-up high position)
        let shoulder = CGPoint(x: 0.3, y: 0.7)
        let elbow    = CGPoint(x: 0.5, y: 0.5)
        let wrist    = CGPoint(x: 0.7, y: 0.7)
        // This particular geometry gives ~127° — let's use a near-collinear set
        let shoulder2 = CGPoint(x: 0.2, y: 0.6)
        let elbow2    = CGPoint(x: 0.5, y: 0.5)
        let wrist2    = CGPoint(x: 0.8, y: 0.6)
        let angle = angleAt(a: shoulder2, vertex: elbow2, b: wrist2)
        XCTAssertGreaterThan(angle, 155.0, "Nearly-extended arm should be > 155° (above UP threshold)")
    }

    func testZeroMagnitude_returnsZero() {
        // Both vectors are zero — should not crash, should return 0.
        let pt = CGPoint(x: 0.5, y: 0.5)
        let angle = angleAt(a: pt, vertex: pt, b: pt)
        XCTAssertEqual(angle, 0.0, "Degenerate input should return 0 without crashing")
    }
}

// MARK: - Rep State Machine Tests

/// Thin synchronous test harness for the rep-counting state machine.
/// Mirrors the exact logic in PoseCounterService so it can be unit-tested
/// without spinning up AVCaptureSession.
private struct RepStateMachine {
    let downThreshold: Double = 90.0
    let upThreshold:   Double = 155.0
    let debounce:      Int    = 4     // must match PoseCounterService.debounceFrameCount

    private(set) var repCount:      Int         = 0
    private(set) var phase:         PushUpPhase = .idle
    private      var hasBeenDown:   Bool        = false
    private      var downFrames:    Int         = 0
    private      var upFrames:      Int         = 0
    var targetReps: Int = 10

    mutating func processAngle(_ angle: Double) {
        if angle < downThreshold {
            downFrames += 1
            upFrames    = 0
            if downFrames >= debounce && phase != .down {
                phase = .down
                hasBeenDown = true
            }
        } else if angle > upThreshold {
            upFrames   += 1
            downFrames  = 0
            if upFrames >= debounce {
                if hasBeenDown && phase == .down {
                    hasBeenDown = false
                    downFrames  = 0
                    upFrames    = 0
                    repCount   += 1
                    phase       = repCount >= targetReps ? .completed : .up
                } else if phase == .idle {
                    phase = .up
                }
            }
        } else {
            downFrames = 0
            upFrames   = 0
        }
    }

    /// Convenience: feed `count` frames at the given angle.
    mutating func feed(angle: Double, frames: Int) {
        for _ in 0..<frames { processAngle(angle) }
    }
}

final class RepStateMachineTests: XCTestCase {

    func testZeroReps_whenNeverMoving() {
        var sm = RepStateMachine()
        sm.feed(angle: 170, frames: 20)   // stays up
        XCTAssertEqual(sm.repCount, 0, "No movement → 0 reps")
    }

    func testOneRep_singleFullCycle() {
        var sm = RepStateMachine()
        // Start in up position
        sm.feed(angle: 170, frames: 5)   // establishes UP phase
        XCTAssertEqual(sm.phase, .up)

        // Go down
        sm.feed(angle: 70, frames: 5)    // triggers DOWN phase (hasBeenDown = true)
        XCTAssertEqual(sm.phase, .down)

        // Come back up
        sm.feed(angle: 170, frames: 5)   // triggers UP + rep count
        XCTAssertEqual(sm.repCount, 1, "One full down→up cycle = 1 rep")
        XCTAssertEqual(sm.phase, .up)
    }

    func testFiveReps_fiveFullCycles() {
        var sm = RepStateMachine()
        sm.feed(angle: 170, frames: 5)   // initial UP

        for _ in 0..<5 {
            sm.feed(angle: 70,  frames: 5)
            sm.feed(angle: 170, frames: 5)
        }

        XCTAssertEqual(sm.repCount, 5, "Five complete cycles = 5 reps")
    }

    func testDebounce_partialFramesDoNotCount() {
        var sm = RepStateMachine()
        sm.feed(angle: 170, frames: 5)

        // Only 3 down-frames (debounce = 4) — should NOT transition to DOWN
        sm.feed(angle: 70, frames: 3)
        XCTAssertNotEqual(sm.phase, .down, "Fewer frames than debounce should NOT transition phase")

        // Come back up — no rep, because we never fully entered DOWN
        sm.feed(angle: 170, frames: 5)
        XCTAssertEqual(sm.repCount, 0, "Partial down without debounce → 0 reps")
    }

    func testNeutralZoneDoesNotCount() {
        var sm = RepStateMachine()
        sm.feed(angle: 170, frames: 5)
        // Angle in neutral zone (90–155) — should not trigger either phase transition
        sm.feed(angle: 120, frames: 10)
        sm.feed(angle: 170, frames: 5)
        XCTAssertEqual(sm.repCount, 0, "Angle in neutral zone should not count a rep")
    }

    func testUpWithoutDown_doesNotCountRep() {
        var sm = RepStateMachine()
        // Feed UP frames without any prior DOWN
        sm.feed(angle: 170, frames: 20)
        XCTAssertEqual(sm.repCount, 0, "UP without prior DOWN should not count a rep")
    }

    func testTargetReached_setsCompletedPhase() {
        var sm = RepStateMachine()
        sm.targetReps = 2
        sm.feed(angle: 170, frames: 5)

        // Rep 1
        sm.feed(angle: 70, frames: 5)
        sm.feed(angle: 170, frames: 5)
        XCTAssertEqual(sm.repCount, 1)
        XCTAssertEqual(sm.phase, .up)

        // Rep 2
        sm.feed(angle: 70, frames: 5)
        sm.feed(angle: 170, frames: 5)
        XCTAssertEqual(sm.repCount, 2)
        XCTAssertEqual(sm.phase, .completed, "Reaching target should set phase to .completed")
    }
}
