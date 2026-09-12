// AloneDetector.swift
// Event stream in, switch action out. Every rule of F-1 to F-3 lives
// here and nowhere else, which is what makes them testable without an event tap.

import Foundation

/// The three numbers that shape the judgement.
public struct DetectorConfiguration: Sendable, Equatable {
  public var leftAction: KeyAction
  public var rightAction: KeyAction
  /// Held longer than this, a ⌘ press is a hold, not a tap (F-3).
  public var aloneTimeout: TimeInterval

  public init(leftAction: KeyAction, rightAction: KeyAction, aloneTimeout: TimeInterval) {
    self.leftAction = leftAction
    self.rightAction = rightAction
    self.aloneTimeout = aloneTimeout
  }

  public init(settings: Settings) {
    self.init(
      leftAction: settings.leftAction,
      rightAction: settings.rightAction,
      aloneTimeout: TimeInterval(settings.aloneTimeoutMilliseconds) / 1000
    )
  }
}

/// Decides whether a ⌘ press was a bare tap.
///
/// A candidate is armed when a ⌘ goes down with no other modifier already
/// held, and disarmed by anything at all that happens before it comes back up.
/// Nothing here ever consumes or rewrites an event — the caller has already
/// passed the real event through untouched (F-4); this only reads a copy of the
/// facts about it.
public struct AloneDetector: Sendable {
  private struct Candidate {
    let keyCode: UInt16
    let downAt: TimeInterval
  }

  public var configuration: DetectorConfiguration

  private var candidate: Candidate?

  public init(configuration: DetectorConfiguration) {
    self.configuration = configuration
  }

  /// Feeds one event and returns the action it completed, if any.
  public mutating func handle(_ event: DetectorEvent) -> KeyAction? {
    switch event.kind {
    case .key, .mouse, .scroll:
      // Any real input while a ⌘ is held means the ⌘ was a modifier, not a tap.
      candidate = nil
      return nil

    case .modifier(let keyCode, isDown: true, let otherModifiersDown):
      if KeyCode.isCommand(keyCode) && !otherModifiersDown {
        candidate = Candidate(keyCode: keyCode, downAt: event.timestamp)
      } else {
        // A second modifier — including the other ⌘ — cancels the tap. Both ⌘
        // down means neither fires, whichever is released first.
        candidate = nil
      }
      return nil

    case .modifier(let keyCode, isDown: false, _):
      guard let armed = candidate, armed.keyCode == keyCode else {
        candidate = nil
        return nil
      }
      candidate = nil
      guard event.timestamp - armed.downAt < configuration.aloneTimeout else { return nil }
      return action(forCommand: keyCode)
    }
  }

  /// Drops any half-finished press. Called when the tap is re-created or the
  /// app is unpaused, so a ⌘ that went down while the app was not watching
  /// cannot complete against a stale timestamp.
  public mutating func reset() {
    candidate = nil
  }

  private func action(forCommand keyCode: UInt16) -> KeyAction? {
    let action =
      keyCode == KeyCode.leftCommand ? configuration.leftAction : configuration.rightAction
    return action == .none ? nil : action
  }
}
