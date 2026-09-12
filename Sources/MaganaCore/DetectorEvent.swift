// DetectorEvent.swift
// The only thing the event tap is allowed to hand to the rest of the app.

import Foundation

/// One input event, reduced to what the alone-press judgement needs.
///
/// Everything that is not a modifier collapses into `.key`, `.mouse` or
/// `.scroll` with no key code attached. That is deliberate and load-bearing:
/// the tap can see every keystroke on the machine, and the app's promise
/// is that no key content is retained even in memory. Reducing at the boundary
/// makes the promise structural instead of a rule someone has to remember.
public struct DetectorEvent: Sendable, Equatable {
  public enum Kind: Sendable, Equatable {
    /// A modifier key changed state.
    ///
    /// `otherModifiersDown` is read out of the event's own flags rather than
    /// accumulated across events. Carrying the whole modifier state on every
    /// event means a missed key-up — the app launching while ⌘ is held, a tap
    /// re-created mid-chord — cannot leave the detector stuck believing a
    /// modifier is still down.
    case modifier(keyCode: UInt16, isDown: Bool, otherModifiersDown: Bool)
    /// A non-modifier key went down. Which key it was is not recorded.
    case key
    /// Any mouse button went down.
    case mouse
    /// A scroll wheel event.
    case scroll
  }

  public let kind: Kind
  /// Seconds on an arbitrary monotonic scale. Only differences are used.
  public let timestamp: TimeInterval

  public init(kind: Kind, timestamp: TimeInterval) {
    self.kind = kind
    self.timestamp = timestamp
  }
}
