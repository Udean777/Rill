import RillDomain
import Testing

@Suite("PageSwipePhysics")
struct PageSwipePhysicsTests {
    private let middlePage = PageSwipeContext(currentPage: 1, pageCount: 3, pageWidth: 1200)
    private let firstPage = PageSwipeContext(currentPage: 0, pageCount: 3, pageWidth: 1200)
    private let lastPage = PageSwipeContext(currentPage: 2, pageCount: 3, pageWidth: 1200)
    private let singlePage = PageSwipeContext(currentPage: 0, pageCount: 1, pageWidth: 1200)

    @Test func `lazy short swipe left advances to next page`() {
        var physics = PageSwipePhysics()
        _ = physics.process(event(dx: 0, phase: .began, time: 1.0), in: middlePage)
        let mid = physics.process(event(dx: -10, phase: .changed, time: 1.04), in: middlePage)
        let endTrack = physics.process(event(dx: -10, phase: .changed, time: 1.08), in: middlePage)
        let settled = physics.process(event(dx: 0, phase: .ended, time: 1.12), in: middlePage)

        #expect(mid == .track(offset: -10 * physics.tuning.dragGain))
        #expect(endTrack == .track(offset: -20 * physics.tuning.dragGain))
        #expect(settled == .settle(pageDelta: 1))
    }

    @Test func `lazy short swipe right returns to previous page`() {
        var physics = PageSwipePhysics()
        _ = physics.process(event(dx: 0, phase: .began, time: 1.0), in: middlePage)
        _ = physics.process(event(dx: 12, phase: .changed, time: 1.05), in: middlePage)
        _ = physics.process(event(dx: 10, phase: .changed, time: 1.10), in: middlePage)
        let settled = physics.process(event(dx: 0, phase: .ended, time: 1.15), in: middlePage)

        #expect(settled == .settle(pageDelta: -1))
    }

    @Test func `quick gentle flick commits even with small travel distance`() {
        var physics = PageSwipePhysics()
        _ = physics.process(event(dx: 0, phase: .began, time: 1.000), in: middlePage)
        // Only 8pt total travel, but fast enough (> 90 pt/s) to register as a flick.
        _ = physics.process(event(dx: -4, phase: .changed, time: 1.016), in: middlePage)
        _ = physics.process(event(dx: -4, phase: .changed, time: 1.032), in: middlePage)
        let settled = physics.process(event(dx: 0, phase: .ended, time: 1.048), in: middlePage)

        #expect(settled == .settle(pageDelta: 1))
    }

    @Test func `tiny slow micro-nudge snaps back to current page`() {
        var physics = PageSwipePhysics()
        _ = physics.process(event(dx: 0, phase: .began, time: 1.0), in: middlePage)
        _ = physics.process(event(dx: -3, phase: .changed, time: 1.15), in: middlePage)
        _ = physics.process(event(dx: -2, phase: .changed, time: 1.30), in: middlePage)
        let settled = physics.process(event(dx: 0, phase: .ended, time: 1.45), in: middlePage)

        #expect(settled == .settle(pageDelta: 0))
    }

    @Test func `deliberate reversal mid-swipe cancels page turn`() {
        var physics = PageSwipePhysics()
        _ = physics.process(event(dx: 0, phase: .began, time: 1.00), in: middlePage)
        _ = physics.process(event(dx: -30, phase: .changed, time: 1.05), in: middlePage)
        _ = physics.process(event(dx: 6, phase: .changed, time: 1.066), in: middlePage)
        _ = physics.process(event(dx: 8, phase: .changed, time: 1.082), in: middlePage)
        let settled = physics.process(event(dx: 0, phase: .ended, time: 1.10), in: middlePage)

        #expect(settled == .settle(pageDelta: 0))
    }

    @Test func `dragging past leading or trailing edge rubber-bands and settles on current page`() {
        var physics = PageSwipePhysics()
        _ = physics.process(event(dx: 0, phase: .began, time: 1.0), in: firstPage)
        let leadingTrack = physics.process(event(dx: 80, phase: .changed, time: 1.05), in: firstPage)
        let leadingSettled = physics.process(event(dx: 0, phase: .ended, time: 1.10), in: firstPage)

        if case .track(let offset) = leadingTrack {
            #expect(offset > 0)
            #expect(offset < physics.tuning.rubberBandLimit)
        } else {
            Issue.record("Expected rubber-banded .track on leading edge")
        }
        #expect(leadingSettled == .settle(pageDelta: 0))

        _ = physics.process(event(dx: 0, phase: .began, time: 2.0), in: lastPage)
        let trailingTrack = physics.process(event(dx: -80, phase: .changed, time: 2.05), in: lastPage)
        let trailingSettled = physics.process(event(dx: 0, phase: .ended, time: 2.10), in: lastPage)

        if case .track(let offset) = trailingTrack {
            #expect(offset < 0)
            #expect(offset > -physics.tuning.rubberBandLimit)
        } else {
            Issue.record("Expected rubber-banded .track on trailing edge")
        }
        #expect(trailingSettled == .settle(pageDelta: 0))
    }

    @Test func `vertical scroll is ignored while slight diagonal horizontal swipe still tracks`() {
        var physics = PageSwipePhysics()
        _ = physics.process(event(dx: 0, phase: .began, time: 1.0), in: middlePage)
        #expect(physics.process(event(dx: -2, dy: 20, phase: .changed, time: 1.02), in: middlePage) == .ignore)
        #expect(physics.process(event(dx: -30, dy: 0, phase: .changed, time: 1.04), in: middlePage) == .ignore)
        #expect(physics.process(event(dx: 0, phase: .ended, time: 1.06), in: middlePage) == .ignore)

        // Slight diagonal swipe locks horizontal and keeps tracking even if later frames drift vertically.
        _ = physics.process(event(dx: 0, phase: .began, time: 2.0), in: middlePage)
        let firstTrack = physics.process(event(dx: -12, dy: 10, phase: .changed, time: 2.02), in: middlePage)
        let secondTrack = physics.process(event(dx: -10, dy: 15, phase: .changed, time: 2.04), in: middlePage)
        let settled = physics.process(event(dx: 0, phase: .ended, time: 2.06), in: middlePage)

        #expect(firstTrack == .track(offset: -12 * physics.tuning.dragGain))
        #expect(secondTrack == .track(offset: -22 * physics.tuning.dragGain))
        #expect(settled == .settle(pageDelta: 1))
    }

    @Test func `began event with non-zero delta starts tracking immediately`() {
        var physics = PageSwipePhysics()
        let beganTrack = physics.process(event(dx: -20, phase: .began, time: 1.0), in: middlePage)
        let settled = physics.process(event(dx: 0, phase: .ended, time: 1.05), in: middlePage)

        #expect(beganTrack == .track(offset: -20 * physics.tuning.dragGain))
        #expect(settled == .settle(pageDelta: 1))
    }

    @Test func `cancelled gesture snaps back without changing page`() {
        var physics = PageSwipePhysics()
        _ = physics.process(event(dx: 0, phase: .began, time: 1.0), in: middlePage)
        _ = physics.process(event(dx: -40, phase: .changed, time: 1.04), in: middlePage)
        let cancelled = physics.process(event(dx: 0, phase: .cancelled, time: 1.08), in: middlePage)

        #expect(cancelled == .settle(pageDelta: 0))
    }

    @Test func `discrete notched wheel flips once per burst and resets after gap`() {
        var physics = PageSwipePhysics()
        let first = physics.process(
            event(dx: -1, phase: .discrete, precise: false, time: 1.0),
            in: middlePage
        )
        let duplicate = physics.process(
            event(dx: -1, phase: .discrete, precise: false, time: 1.1),
            in: middlePage
        )
        let afterGap = physics.process(
            event(dx: 1, phase: .discrete, precise: false, time: 1.6),
            in: middlePage
        )

        #expect(first == .settle(pageDelta: 1))
        #expect(duplicate == .ignore)
        #expect(afterGap == .settle(pageDelta: -1))
    }

    @Test func `single page grid ignores swipes`() {
        var physics = PageSwipePhysics()
        #expect(physics.process(event(dx: -30, phase: .began, time: 1.0), in: singlePage) == .ignore)
        #expect(physics.process(event(dx: 0, phase: .ended, time: 1.05), in: singlePage) == .ignore)
    }

    private func event(
        dx: Double,
        dy: Double = 0,
        phase: PageSwipePhase,
        precise: Bool = true,
        time: Double
    ) -> PageSwipeEvent {
        PageSwipeEvent(
            deltaX: dx,
            deltaY: dy,
            phase: phase,
            hasPreciseDeltas: precise,
            timestamp: time
        )
    }
}
