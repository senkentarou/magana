// SwitchDecision.swift
// The last gate before a key is posted: whether posting would do anything.

import Foundation

/// What should happen when a tap has asked for `target`.
public enum SwitchOutcome: Sendable, Equatable {
  /// Post the key.
  case post
  /// Already on that input source. F-1 and F-2 call this out by name: posting
  /// a key that changes nothing is the failure, not a harmless no-op.
  case alreadyThere
  /// かな with no Japanese IME enabled has nowhere to go. The menu already
  /// says so, and the key would do nothing.
  case noJapaneseInputSource
}

/// Decides whether posting a switch key would change anything.
///
/// A pure function of three facts, but it used to sit inside `AppController`
/// reading a live service, so nothing in `swift test` covered the two
/// conditions F-1 and F-2 are written in terms of.
public enum SwitchDecision {
  public static func outcome(
    target: InputSourceKind,
    current: InputSourceKind,
    hasJapaneseSource: Bool
  ) -> SwitchOutcome {
    guard current != target else { return .alreadyThere }
    guard target == .eisuu || hasJapaneseSource else { return .noJapaneseInputSource }
    return .post
  }
}

/// Which ⌘ keys are held right now, for the key caps in the settings window.
///
/// Nothing but the side is kept. The events it is fed have already been reduced
/// at the tap boundary, so there is no key content here to leak.
public struct HeldCommandKeys: Sendable, Equatable {
  public private(set) var sides: Set<CommandSide> = []

  public init() {}

  public mutating func handle(_ event: DetectorEvent) {
    guard case .modifier(let keyCode, let isDown, _) = event.kind,
      let side = CommandSide(keyCode: keyCode)
    else { return }

    if isDown {
      sides.insert(side)
    } else {
      sides.remove(side)
    }
  }

  /// Clears the lit caps. Called when the tap stops, since a key released while
  /// the app was not watching would otherwise stay lit for good.
  public mutating func reset() {
    sides.removeAll()
  }
}
