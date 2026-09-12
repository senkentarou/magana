// KeyAction.swift
// What a single ⌘ press is allowed to do, and the two input-source states the
// app can put macOS into.

/// The action bound to one side of the ⌘ key.
public enum KeyAction: String, Codable, Sendable, CaseIterable {
  case eisuu
  case kana
  case none
}

/// The two states this app distinguishes. macOS has many input sources; every
/// one of them reads as either "typing Japanese" or "not typing Japanese",
/// which is the only distinction the ⌘ keys express.
public enum InputSourceKind: String, Sendable {
  case eisuu
  case kana
}

extension KeyAction {
  /// The input source this action targets, or nil for `.none`.
  public var targetInputSource: InputSourceKind? {
    switch self {
    case .eisuu: return .eisuu
    case .kana: return .kana
    case .none: return nil
    }
  }
}

/// Virtual key codes this app cares about.
///
/// Only these four are ever named. The tap sees every key on the keyboard, and
/// the way this app keeps its promise not to retain key content is
/// that no other key code reaches a stored property — `DetectorEvent` collapses
/// them all into `.key`.
public enum KeyCode {
  public static let leftCommand: UInt16 = 55
  public static let rightCommand: UInt16 = 54
  /// The JIS 英数 key. Posting it is how the switch to ABC is performed.
  public static let eisuu: UInt16 = 0x66
  /// The JIS かな key.
  public static let kana: UInt16 = 0x68

  public static func isCommand(_ keyCode: UInt16) -> Bool {
    keyCode == leftCommand || keyCode == rightCommand
  }
}

/// Which of the two ⌘ keys an event came from.
///
/// The side is the whole of what leaves the tap boundary for display purposes:
/// the settings window lights the cap of the ⌘ being held, and to do that it
/// needs to know left from right and nothing else.
public enum CommandSide: String, Sendable, Hashable, CaseIterable {
  case left
  case right

  public init?(keyCode: UInt16) {
    switch keyCode {
    case KeyCode.leftCommand: self = .left
    case KeyCode.rightCommand: self = .right
    default: return nil
    }
  }
}

extension InputSourceKind {
  /// The key code that asks macOS to move to this input source.
  public var switchKeyCode: UInt16 {
    switch self {
    case .eisuu: return KeyCode.eisuu
    case .kana: return KeyCode.kana
    }
  }
}
