import Foundation

/// Direction of a multi-finger trackpad pinch gesture.
public enum TrackpadPinchDirection: Sendable, Equatable {
    case pinchIn
    case pinchOut
}

/// Port for observing global multi-finger trackpad pinch gestures.
public protocol TrackpadGestureMonitoring: Sendable {
    @MainActor func start(
        sensitivity: Double,
        onPinch: @escaping @MainActor (TrackpadPinchDirection) -> Void
    )
    @MainActor func updateSensitivity(_ sensitivity: Double)
    @MainActor func stop()
}

/// A single 2D touch point in normalized trackpad coordinates (`0…1`).
public struct TrackpadTouchPoint: Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Pure state machine that detects 4- or 5-finger pinch-in and pinch-out
/// gestures from sequential touch frames.
public struct TrackpadPinchDetector: Sendable {
    private var initialRadius: Double?
    private var hasTriggeredInCurrentGesture = false
    public var sensitivity: Double

    public init(sensitivity: Double = 0.22) {
        self.sensitivity = Self.clampSensitivity(sensitivity)
    }

    private static func clampSensitivity(_ value: Double) -> Double {
        min(max(value, 0.10), 0.45)
    }

    /// Processes one contact frame of active touching points and returns a
    /// `TrackpadPinchDirection` when the gesture crosses the pinch threshold.
    public mutating func processFrame(touches: [TrackpadTouchPoint]) -> TrackpadPinchDirection? {
        guard touches.count >= 4 else {
            initialRadius = nil
            hasTriggeredInCurrentGesture = false
            return nil
        }

        let radius = averageRadius(for: touches)
        guard radius > 0.01 else { return nil }

        guard let baseline = initialRadius else {
            initialRadius = radius
            return nil
        }

        guard !hasTriggeredInCurrentGesture else {
            return nil
        }

        let clamped = Self.clampSensitivity(sensitivity)
        let ratio = radius / baseline
        if ratio <= (1.0 - clamped) {
            hasTriggeredInCurrentGesture = true
            return .pinchIn
        }
        if ratio >= (1.0 + clamped) {
            hasTriggeredInCurrentGesture = true
            return .pinchOut
        }
        return nil
    }

    private func averageRadius(for touches: [TrackpadTouchPoint]) -> Double {
        let count = Double(touches.count)
        let centerX = touches.reduce(0) { $0 + $1.x } / count
        let centerY = touches.reduce(0) { $0 + $1.y } / count
        let totalDistance = touches.reduce(0.0) { partial, point in
            let dx = point.x - centerX
            let dy = point.y - centerY
            return partial + hypot(dx, dy)
        }
        return totalDistance / count
    }
}
