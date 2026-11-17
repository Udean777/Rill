import Darwin
import Foundation
import os
import RillDomain
import Synchronization

/// Observes global multi-finger trackpad contact frames via Apple's
/// `MultitouchSupport.framework` (ADR-010) and emits 4-finger pinch-in /
/// pinch-out events to the main actor.
@MainActor
public final class TrackpadPinchMonitor: TrackpadGestureMonitoring {
    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "trackpad")
    private var detector = TrackpadPinchDetector()
    private var onPinch: (@MainActor (TrackpadPinchDirection) -> Void)?
    private var isRunning = false
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var activeDevices: [UnsafeMutableRawPointer] = []

    public init() {}

    public func start(
        sensitivity: Double,
        onPinch: @escaping @MainActor (TrackpadPinchDirection) -> Void
    ) {
        detector.sensitivity = sensitivity
        self.onPinch = onPinch
        guard !isRunning else { return }

        guard let functions = loadMultitouchFunctions() else {
            log.info("MultitouchSupport unavailable; trackpad pinch gesture disabled")
            return
        }

        guard let deviceListUnmanaged = functions.createList() else {
            log.info("No multitouch trackpad devices found")
            return
        }

        let deviceList = deviceListUnmanaged.takeRetainedValue()
        let count = CFArrayGetCount(deviceList)
        guard count > 0 else { return }

        TrackpadPinchBridge.activeMonitor = self
        for index in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(deviceList, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: rawPtr)
            functions.registerCallback(device, multitouchContactCallback)
            _ = functions.start(device, 0)
            activeDevices.append(device)
        }
        isRunning = !activeDevices.isEmpty
    }

    public func updateSensitivity(_ sensitivity: Double) {
        detector.sensitivity = sensitivity
    }

    public func stop() {
        guard isRunning else { return }
        if let functions = loadMultitouchFunctions() {
            for device in activeDevices {
                functions.unregisterCallback(device, multitouchContactCallback)
                _ = functions.stop(device)
            }
        }
        activeDevices.removeAll()
        if TrackpadPinchBridge.activeMonitor === self {
            TrackpadPinchBridge.activeMonitor = nil
        }
        isRunning = false
        onPinch = nil
    }

    fileprivate func handleTouches(_ touches: [TrackpadTouchPoint]) {
        guard let direction = detector.processFrame(touches: touches) else { return }
        onPinch?(direction)
    }

    private func loadMultitouchFunctions() -> MultitouchFunctions? {
        if frameworkHandle == nil {
            frameworkHandle = dlopen(
                "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
                RTLD_LAZY
            )
        }
        guard let handle = frameworkHandle,
              let createListSym = dlsym(handle, "MTDeviceCreateList"),
              let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let unregisterSym = dlsym(handle, "MTUnregisterContactFrameCallback"),
              let startSym = dlsym(handle, "MTDeviceStart"),
              let stopSym = dlsym(handle, "MTDeviceStop") else {
            return nil
        }
        return MultitouchFunctions(
            createList: unsafeBitCast(createListSym, to: MTDeviceCreateListFn.self),
            registerCallback: unsafeBitCast(registerSym, to: MTRegisterCallbackFn.self),
            unregisterCallback: unsafeBitCast(unregisterSym, to: MTUnregisterCallbackFn.self),
            start: unsafeBitCast(startSym, to: MTDeviceStartFn.self),
            stop: unsafeBitCast(stopSym, to: MTDeviceStopFn.self)
        )
    }
}

private enum TrackpadPinchBridge {
    @MainActor static weak var activeMonitor: TrackpadPinchMonitor?
    static let isTrackingFourFingers = Atomic<Bool>(false)
}

private typealias MTContactCallback = @convention(c) (
    UnsafeMutableRawPointer?,
    UnsafeRawPointer?,
    Int32,
    Double,
    Int32
) -> Int32

private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTRegisterCallbackFn = @convention(c) (UnsafeMutableRawPointer, MTContactCallback) -> Void
private typealias MTUnregisterCallbackFn = @convention(c) (UnsafeMutableRawPointer, MTContactCallback) -> Void
private typealias MTDeviceStartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
private typealias MTDeviceStopFn = @convention(c) (UnsafeMutableRawPointer) -> Int32

private struct MultitouchFunctions {
    let createList: MTDeviceCreateListFn
    let registerCallback: MTRegisterCallbackFn
    let unregisterCallback: MTUnregisterCallbackFn
    let start: MTDeviceStartFn
    let stop: MTDeviceStopFn
}

private struct MTPoint {
    var x: Float
    var y: Float
}

private struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

/// ABI-compatible layout for `MTTouch` in `MultitouchSupport.framework`.
private struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector
    var zero2: Int32
    var zero3: Int32
    var density: Float
}

/// C callback cannot capture context; hops to `@MainActor` via `TrackpadPinchBridge`.
private let multitouchContactCallback: MTContactCallback = { _, rawData, numFingers, _, _ in
    guard let rawData, numFingers >= 4 else {
        if TrackpadPinchBridge.isTrackingFourFingers.exchange(false, ordering: .relaxed) {
            Task { @MainActor in
                TrackpadPinchBridge.activeMonitor?.handleTouches([])
            }
        }
        return 0
    }

    let data = rawData.assumingMemoryBound(to: MTTouch.self)
    var points: [TrackpadTouchPoint] = []
    points.reserveCapacity(Int(numFingers))
    for index in 0..<Int(numFingers) {
        let touch = data[index]
        // State 4 corresponds to active touching contact on the trackpad surface.
        if touch.state == 4 {
            points.append(
                TrackpadTouchPoint(
                    x: Double(touch.normalizedVector.position.x),
                    y: Double(touch.normalizedVector.position.y)
                )
            )
        }
    }

    guard points.count >= 4 else {
        if TrackpadPinchBridge.isTrackingFourFingers.exchange(false, ordering: .relaxed) {
            Task { @MainActor in
                TrackpadPinchBridge.activeMonitor?.handleTouches([])
            }
        }
        return 0
    }

    TrackpadPinchBridge.isTrackingFourFingers.store(true, ordering: .relaxed)
    let snapshot = points
    Task { @MainActor in
        TrackpadPinchBridge.activeMonitor?.handleTouches(snapshot)
    }
    return 0
}
