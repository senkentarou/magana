// KeyboardRegistry.swift
// Answers whether a JIS keyboard is attached (F-9).

import Foundation
import IOKit
import IOKit.hid
import MaganaCore

/// Reads keyboard country codes out of the IOKit registry.
///
/// Registry properties only — no `IOHIDDeviceOpen`, no input value callback.
/// That distinction is the whole reason this file exists in this shape:
/// subscribing to HID input to learn which device sent a key would require the
/// Input Monitoring permission on top of Accessibility, and "one permission"
/// is a goal, not a detail.
///
/// The cost is that a key cannot be attributed to the keyboard it came from —
/// `CGEvent` carries no usable device identity, and the private call that would
/// give one is not in the SDK. So this is the alternative:
/// while a JIS keyboard is connected, the switch stands down entirely. A JIS
/// keyboard has 英数 and かな keys of its own, so nothing is lost on it.
@MainActor
final class KeyboardRegistry {
  private(set) var hasJISKeyboard = false
  var onChange: (() -> Void)?

  /// Held, not read. The port and its iterators are what keep the connect and
  /// disconnect notifications arriving; letting them go stops the JIS state
  /// updating, silently and only for keyboards plugged in later.
  private var notifyPort: IONotificationPortRef?
  private var matchedIterator: io_iterator_t = 0
  private var terminatedIterator: io_iterator_t = 0

  func start() {
    refresh()

    guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
    IONotificationPortSetDispatchQueue(port, .main)
    notifyPort = port

    let context = Unmanaged.passUnretained(self).toOpaque()
    // Two calls, two matching dictionaries: IOServiceAddMatchingNotification
    // consumes a reference to the dictionary it is given.
    register(kIOFirstMatchNotification, into: &matchedIterator, port: port, context: context)
    register(kIOTerminatedNotification, into: &terminatedIterator, port: port, context: context)
  }

  fileprivate func refresh() {
    let found = Self.scanForJISKeyboard()
    guard found != hasJISKeyboard else { return }
    hasJISKeyboard = found
    onChange?()
  }

  private func register(
    _ notificationType: String,
    into iterator: inout io_iterator_t,
    port: IONotificationPortRef,
    context: UnsafeMutableRawPointer
  ) {
    guard let matching = Self.keyboardMatchingDictionary() else { return }
    let result = IOServiceAddMatchingNotification(
      port, notificationType, matching, keyboardChangeCallback, context, &iterator)
    guard result == KERN_SUCCESS else { return }
    // The iterator must be drained once for the notification to arm at all.
    drain(iterator)
  }

  private static func keyboardMatchingDictionary() -> CFMutableDictionary? {
    guard let matching = IOServiceMatching(kIOHIDDeviceKey) as NSMutableDictionary? else {
      return nil
    }
    matching[kIOHIDPrimaryUsagePageKey] = kHIDPage_GenericDesktop
    matching[kIOHIDPrimaryUsageKey] = kHIDUsage_GD_Keyboard
    return matching as CFMutableDictionary
  }

  private static func scanForJISKeyboard() -> Bool {
    guard let matching = keyboardMatchingDictionary() else { return false }
    var iterator: io_iterator_t = 0
    guard
      IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS
    else { return false }
    defer { IOObjectRelease(iterator) }

    while case let service = IOIteratorNext(iterator), service != 0 {
      defer { IOObjectRelease(service) }
      let property = IORegistryEntryCreateCFProperty(
        service, kIOHIDCountryCodeKey as CFString, kCFAllocatorDefault, 0)
      guard let countryCode = property?.takeRetainedValue() as? Int else { continue }
      if KeyboardCountry.isJIS(countryCode: countryCode) { return true }
    }
    return false
  }
}

/// Consumes every entry so the notification re-arms; the identity of the
/// devices does not matter, only that the set changed.
private func drain(_ iterator: io_iterator_t) {
  while case let service = IOIteratorNext(iterator), service != 0 {
    IOObjectRelease(service)
  }
}

private func keyboardChangeCallback(context: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
  drain(iterator)
  guard let context else { return }
  let registry = Unmanaged<KeyboardRegistry>.fromOpaque(context).takeUnretainedValue()
  // IONotificationPortSetDispatchQueue put this callback on the main queue.
  MainActor.assumeIsolated { registry.refresh() }
}
