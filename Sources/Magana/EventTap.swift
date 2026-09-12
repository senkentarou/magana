// EventTap.swift
// Watches the ⌘ keys without ever getting in their way.

import CoreGraphics
import Foundation
import MaganaCore
import os

/// A `CGEventTap` that reads events and always returns them untouched.
///
/// The tap is created with `.defaultTap` rather than `.listenOnly` because the
/// permission each one needs differs: an active tap runs on Accessibility,
/// which `CGEventPost` also needs, while a listen-only tap runs on Input
/// Monitoring and would leave posting still asking for Accessibility on top.
/// One permission instead of two is a stated goal,
/// and the cost — being able to swallow an event by mistake — is paid off by
/// every exit from the callback returning the event it was handed.
@MainActor
final class EventTap {
  /// Called for every event that concerns the alone-press judgement.
  var onEvent: ((DetectorEvent) -> Void)?
  /// Called when macOS disables the tap, which is also how a revoked
  /// Accessibility grant shows up.
  var onSystemDisable: (() -> Void)?

  private(set) var isRunning = false
  private var machPort: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "magana", category: "tap")

  /// Creates the tap. Returns false when Accessibility has not been granted —
  /// `tapCreate` is the only reliable test, since `AXIsProcessTrusted` can lag
  /// behind a grant that was just revoked.
  @discardableResult
  func start() -> Bool {
    guard !isRunning else { return true }

    let mask: CGEventMask =
      (1 << CGEventType.flagsChanged.rawValue)
      | (1 << CGEventType.keyDown.rawValue)
      | (1 << CGEventType.leftMouseDown.rawValue)
      | (1 << CGEventType.rightMouseDown.rawValue)
      | (1 << CGEventType.otherMouseDown.rawValue)
      | (1 << CGEventType.scrollWheel.rawValue)

    guard
      let port = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: eventTapCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else {
      logger.error("tapCreate failed; Accessibility is probably not granted")
      return false
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
    // .commonModes, not .defaultMode: while a menu is tracking, the run loop
    // switches to the event-tracking mode, and a tap registered only for the
    // default mode would stop seeing keys for as long as the menu is open.
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: port, enable: true)

    machPort = port
    runLoopSource = source
    isRunning = true
    Diagnostics.trace("tap created and enabled")
    return true
  }

  func stop() {
    guard let port = machPort else { return }
    CGEvent.tapEnable(tap: port, enable: false)
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
    CFMachPortInvalidate(port)
    machPort = nil
    runLoopSource = nil
    isRunning = false
  }

  /// Re-arms a tap that macOS switched off. The system does this when the
  /// callback overran its deadline or when a burst of input arrived during a
  /// modal loop; leaving it off is what "the switch stopped working after
  /// waking from sleep" looks like.
  fileprivate func reenableAfterSystemDisable() {
    guard let port = machPort, isRunning else { return }
    logger.warning("tap disabled by the system; re-enabling")
    CGEvent.tapEnable(tap: port, enable: true)
    onSystemDisable?()
  }

  fileprivate func deliver(_ event: DetectorEvent) {
    Diagnostics.trace("tap \(Diagnostics.describe(event)) t=\(event.timestamp)")
    onEvent?(event)
  }
}

/// `CGEventTimestamp` is nanoseconds since startup, not mach absolute time
/// ticks — CGEventTypes.h says so outright ("roughly, nanoseconds since
/// startup"), and the two are not interchangeable.
///
/// Converting through `mach_timebase_info` was this app's first bug: on Apple
/// Silicon the timebase is 125/3, so every measured duration came out 41.67×
/// too long and a 111ms tap was judged a 4.6 second hold. Nothing ever
/// switched. `AloneDetector` was right the whole time; the unit was wrong
/// before the numbers reached it.
private let nanosecondsPerSecond: Double = 1_000_000_000

private func eventTapCallback(
  proxy: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  // Every path out of this function returns the event exactly as it arrived.
  // Nothing is consumed, rewritten or delayed (F-4).
  _ = proxy
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()

  // The facts are read out of the CGEvent here and the event itself never
  // crosses into the isolated closure: a CGEvent is not Sendable, and holding
  // one past the callback is exactly the way to make a tap misbehave.
  switch type {
  case .tapDisabledByTimeout, .tapDisabledByUserInput:
    // The tap source lives on the main run loop, so this callback is on the
    // main thread by construction.
    MainActor.assumeIsolated { tap.reenableAfterSystemDisable() }

  default:
    // Our own 英数 / かな keys come back around through this tap. Letting them
    // through as ordinary keys would cancel a ⌘ press that is still in flight,
    // so they are recognised by the marker on their event source.
    let isOwnEvent =
      event.getIntegerValueField(.eventSourceUserData) == EventSourceMarker.magana
    if !isOwnEvent, let kind = detectorEventKind(type: type, event: event) {
      let detected = DetectorEvent(
        kind: kind, timestamp: Double(event.timestamp) / nanosecondsPerSecond)
      MainActor.assumeIsolated { tap.deliver(detected) }
    }
  }

  return Unmanaged.passUnretained(event)
}

private func detectorEventKind(type: CGEventType, event: CGEvent) -> DetectorEvent.Kind? {
  switch type {
  case .flagsChanged:
    return ModifierFlags.detectorKind(
      keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
      flags: event.flags.rawValue)
  case .keyDown:
    return .key
  case .leftMouseDown, .rightMouseDown, .otherMouseDown:
    return .mouse
  case .scrollWheel:
    return .scroll
  default:
    return nil
  }
}
