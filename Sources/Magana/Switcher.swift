// Switcher.swift
// Sends the 英数 / かな keys that actually change the input source.

import CoreGraphics
import MaganaCore

/// Posts the JIS 英数 / かな key codes.
///
/// Posting the key rather than calling `TISSelectInputSource` is deliberate:
/// that call is reported to move the menu bar indicator while leaving typing
/// in the old source until the next focus change. Posting the key also means
/// the IME's own 英数 / かな settings still decide what happens.
@MainActor
final class Switcher {
  private let source: CGEventSource?

  init() {
    // .privateState, not .hidSystemState: a private source carries no modifier
    // state of its own, so the posted key cannot inherit a ⌘ or ⇧ the user
    // happens to still be holding and arrive as a chord.
    source = CGEventSource(stateID: .privateState)
    source?.userData = EventSourceMarker.magana
  }

  func send(_ kind: InputSourceKind) {
    let keyCode = kind.switchKeyCode
    for isDown in [true, false] {
      guard
        let event = CGEvent(
          keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
      else { continue }
      event.flags = []
      event.post(tap: .cghidEventTap)
    }
  }
}
