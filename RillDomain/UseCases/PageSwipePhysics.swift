import Foundation

/// Phase of a horizontal scroll gesture fed into ``PageSwipePhysics``.
public enum PageSwipePhase: Sendable, Equatable {
    case began
    case changed
    case ended
    case cancelled
    case discrete
}

/// Single scroll event snapshot delivered to ``PageSwipePhysics``.
public struct PageSwipeEvent: Sendable, Equatable {
    public let deltaX: Double
    public let deltaY: Double
    public let phase: PageSwipePhase
    public let hasPreciseDeltas: Bool
    public let timestamp: Double

    public init(
        deltaX: Double,
        deltaY: Double,
        phase: PageSwipePhase,
        hasPreciseDeltas: Bool,
        timestamp: Double
    ) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.phase = phase
        self.hasPreciseDeltas = hasPreciseDeltas
        self.timestamp = timestamp
    }
}

/// Pager bounds and geometry needed to compute swipe offsets and page turns.
public struct PageSwipeContext: Sendable, Equatable {
    public let currentPage: Int
    public let pageCount: Int
    public let pageWidth: Double

    public init(currentPage: Int, pageCount: Int, pageWidth: Double) {
        self.currentPage = currentPage
        self.pageCount = pageCount
        self.pageWidth = pageWidth
    }
}

/// Visual or navigation action produced by ``PageSwipePhysics`` for a scroll event.
public enum PageSwipeOutput: Sendable, Equatable {
    /// The event is not part of an active horizontal page swipe.
    case ignore
    /// Update the live horizontal drag offset (in points) without animation.
    case track(offset: Double)
    /// Finish the gesture, animating to `currentPage + pageDelta` and zero offset.
    case settle(pageDelta: Int)
}

/// Pure gesture state machine and physics for interactive horizontal page swiping.
///
/// Tuned to feel light and responsive: trackpad deltas are amplified so pages
/// glide effortlessly under the fingers, edges rubber-band softly, and even a
/// short or gentle swipe commits cleanly to the adjacent page on release.
public struct PageSwipePhysics: Sendable {
    /// Tunable thresholds and feel parameters for page swiping.
    public struct Tuning: Sendable, Equatable {
        /// Multiplier applied to raw trackpad horizontal deltas while dragging.
        public var dragGain: Double
        /// Minimum raw horizontal travel (points) to commit a page turn on release.
        public var commitDistance: Double
        /// Minimum horizontal flick velocity (raw points/second) to commit a page turn.
        public var commitVelocity: Double
        /// Minimum projected travel (`rawDelta + velocity * 0.12`) to commit a gentle flick.
        public var projectedCommitDistance: Double
        /// Opposing release velocity (raw points/second) that cancels a small drag.
        public var opposingCancelVelocity: Double
        /// Maximum rubber-band excursion (points) when dragging past the first or last page.
        public var rubberBandLimit: Double
        /// Maximum fraction of `pageWidth` a single interactive drag can visually travel.
        public var maxDragFraction: Double
        /// Minimum raw travel for non-phase precise scroll devices before flipping.
        public var discreteCommitDistance: Double
        /// Idle gap (seconds) that starts a fresh discrete scroll gesture.
        public var discreteResetInterval: Double

        public init(
            dragGain: Double = 1.85,
            commitDistance: Double = 18,
            commitVelocity: Double = 90,
            projectedCommitDistance: Double = 22,
            opposingCancelVelocity: Double = 160,
            rubberBandLimit: Double = 110,
            maxDragFraction: Double = 0.85,
            discreteCommitDistance: Double = 10,
            discreteResetInterval: Double = 0.35
        ) {
            self.dragGain = dragGain
            self.commitDistance = commitDistance
            self.commitVelocity = commitVelocity
            self.projectedCommitDistance = projectedCommitDistance
            self.opposingCancelVelocity = opposingCancelVelocity
            self.rubberBandLimit = rubberBandLimit
            self.maxDragFraction = maxDragFraction
            self.discreteCommitDistance = discreteCommitDistance
            self.discreteResetInterval = discreteResetInterval
        }

        public static let `default` = Tuning()
    }

    private enum AxisLock: Sendable {
        case undecided
        case horizontal
        case vertical
    }

    public let tuning: Tuning

    private var axisLock: AxisLock = .undecided
    private var rawDelta: Double = 0
    private var velocity: Double = 0
    private var lastTimestamp: Double = 0
    private var didTrack = false
    private var didCommitDiscrete = false

    public init(tuning: Tuning = .default) {
        self.tuning = tuning
    }

    /// Clears any in-flight gesture state.
    public mutating func reset() {
        axisLock = .undecided
        rawDelta = 0
        velocity = 0
        lastTimestamp = 0
        didTrack = false
        didCommitDiscrete = false
    }

    /// Processes one scroll event and returns the next visual or navigation action.
    public mutating func process(
        _ event: PageSwipeEvent,
        in context: PageSwipeContext
    ) -> PageSwipeOutput {
        guard context.pageCount > 1 else {
            return .ignore
        }

        switch event.phase {
        case .began:
            axisLock = .undecided
            rawDelta = 0
            velocity = 0
            lastTimestamp = event.timestamp
            didTrack = false
            didCommitDiscrete = false
            if abs(event.deltaX) >= 0.25 || abs(event.deltaY) >= 0.25 {
                return processChanged(event, in: context)
            }
            return .ignore

        case .changed:
            return processChanged(event, in: context)

        case .ended:
            return processEnded(in: context)

        case .cancelled:
            let wasTracking = didTrack
            reset()
            return wasTracking ? .settle(pageDelta: 0) : .ignore

        case .discrete:
            return processDiscrete(event, in: context)
        }
    }

    private mutating func processChanged(
        _ event: PageSwipeEvent,
        in context: PageSwipeContext
    ) -> PageSwipeOutput {
        if axisLock == .undecided {
            guard abs(event.deltaX) >= 0.25 || abs(event.deltaY) >= 0.25 else {
                lastTimestamp = event.timestamp
                return .ignore
            }
            // Slightly generous toward horizontal because paged mode only scrolls horizontally.
            if abs(event.deltaX) >= abs(event.deltaY) * 0.75 {
                axisLock = .horizontal
            } else {
                axisLock = .vertical
                return .ignore
            }
        }

        guard axisLock == .horizontal else {
            return .ignore
        }

        let elapsed = event.timestamp - lastTimestamp
        if lastTimestamp > 0, elapsed > 0, elapsed <= 0.25 {
            let clampedElapsed = max(elapsed, 1.0 / 240.0)
            let instantVelocity = event.deltaX / clampedElapsed
            velocity = velocity == 0
                ? instantVelocity
                : (velocity * 0.65 + instantVelocity * 0.35)
        }
        lastTimestamp = event.timestamp

        rawDelta += event.deltaX
        didTrack = true

        let visualOffset = visualOffset(forRawDelta: rawDelta, in: context)
        return .track(offset: visualOffset)
    }

    private mutating func processEnded(in context: PageSwipeContext) -> PageSwipeOutput {
        let wasTracking = didTrack
        let finalDelta = rawDelta
        let finalVelocity = velocity
        reset()

        guard wasTracking else {
            return .ignore
        }

        let primarySignal = finalDelta != 0 ? finalDelta : finalVelocity
        let direction = primarySignal < 0 ? 1 : (primarySignal > 0 ? -1 : 0)
        let targetPage = context.currentPage + direction

        guard direction != 0, (0..<context.pageCount).contains(targetPage) else {
            return .settle(pageDelta: 0)
        }

        // If the user started dragging one way then deliberately reversed back, cancel the turn.
        let isOpposingReversal = finalDelta * finalVelocity < 0
            && abs(finalVelocity) >= tuning.opposingCancelVelocity
            && abs(finalDelta) < tuning.commitDistance * 4
        if isOpposingReversal {
            return .settle(pageDelta: 0)
        }

        // Negative delta/velocity moves forward (+1); positive moves backward (-1).
        let projected = finalDelta + finalVelocity * 0.12
        let hasDistance = abs(finalDelta) >= tuning.commitDistance
        let hasVelocity = abs(finalVelocity) >= tuning.commitVelocity
            && (finalVelocity * Double(direction) < 0)
        let hasProjected = abs(projected) >= tuning.projectedCommitDistance
            && (projected * Double(direction) < 0)

        if hasDistance || hasVelocity || hasProjected {
            return .settle(pageDelta: direction)
        }
        return .settle(pageDelta: 0)
    }

    private mutating func processDiscrete(
        _ event: PageSwipeEvent,
        in context: PageSwipeContext
    ) -> PageSwipeOutput {
        if lastTimestamp == 0 || event.timestamp - lastTimestamp > tuning.discreteResetInterval {
            rawDelta = 0
            didCommitDiscrete = false
        }
        lastTimestamp = event.timestamp

        guard !didCommitDiscrete,
              event.deltaX != 0,
              abs(event.deltaX) > abs(event.deltaY) else {
            return .ignore
        }

        if !event.hasPreciseDeltas {
            didCommitDiscrete = true
            let direction = event.deltaX < 0 ? 1 : -1
            let targetPage = context.currentPage + direction
            return (0..<context.pageCount).contains(targetPage) ? .settle(pageDelta: direction) : .ignore
        }

        rawDelta += event.deltaX
        guard abs(rawDelta) >= tuning.discreteCommitDistance else {
            return .ignore
        }

        didCommitDiscrete = true
        let direction = rawDelta < 0 ? 1 : -1
        let targetPage = context.currentPage + direction
        return (0..<context.pageCount).contains(targetPage) ? .settle(pageDelta: direction) : .ignore
    }

    private func visualOffset(
        forRawDelta rawDelta: Double,
        in context: PageSwipeContext
    ) -> Double {
        let amplified = rawDelta * tuning.dragGain
        let isPastLeadingEdge = context.currentPage == 0 && amplified > 0
        let isPastTrailingEdge = context.currentPage >= context.pageCount - 1 && amplified < 0

        if isPastLeadingEdge || isPastTrailingEdge {
            let limit = tuning.rubberBandLimit
            let damped = limit * (1.0 - exp(-abs(amplified) / (limit * 2.2)))
            return amplified >= 0 ? damped : -damped
        }

        let maxOffset = max(context.pageWidth * tuning.maxDragFraction, 1)
        return min(max(amplified, -maxOffset), maxOffset)
    }
}
