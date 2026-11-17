import Foundation
import RillDomain
import Testing

@Suite("TrackpadPinchDetector")
struct TrackpadPinchDetectorTests {
    @Test func `ignores fewer than four fingers`() {
        var detector = TrackpadPinchDetector(sensitivity: 0.20)
        let threeWide = spreadPoints(count: 3, radius: 0.40)
        let threeTight = spreadPoints(count: 3, radius: 0.10)

        #expect(detector.processFrame(touches: threeWide) == nil)
        #expect(detector.processFrame(touches: threeTight) == nil)
    }

    @Test func `triggers pinchIn once when four fingers move closer`() {
        var detector = TrackpadPinchDetector(sensitivity: 0.22)

        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.35)) == nil)
        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.22)) == .pinchIn)
        // Does not re-trigger within the same gesture.
        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.15)) == nil)
    }

    @Test func `triggers pinchOut once when four fingers spread apart`() {
        var detector = TrackpadPinchDetector(sensitivity: 0.22)

        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.15)) == nil)
        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.25)) == .pinchOut)
        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.35)) == nil)
    }

    @Test func `resets after fingers lift so next gesture triggers`() {
        var detector = TrackpadPinchDetector(sensitivity: 0.22)

        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.35)) == nil)
        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.20)) == .pinchIn)
        #expect(detector.processFrame(touches: []) == nil)

        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.15)) == nil)
        #expect(detector.processFrame(touches: spreadPoints(count: 4, radius: 0.25)) == .pinchOut)
    }

    private func spreadPoints(count: Int, radius: Double) -> [TrackpadTouchPoint] {
        (0..<count).map { index in
            let angle = (Double(index) / Double(count)) * (2.0 * .pi)
            return TrackpadTouchPoint(
                x: 0.5 + radius * cos(angle),
                y: 0.5 + radius * sin(angle)
            )
        }
    }
}
