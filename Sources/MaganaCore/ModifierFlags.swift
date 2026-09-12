// ModifierFlags.swift
// Turns one modifier event's raw flag word into the two facts the alone-press
// judgement needs: is this key down, and is anything else held with it.

import Foundation

/// The device-dependent modifier bits, and what they mean for one key.
///
/// This lived next to the event tap, where nothing could reach it: every
/// `AloneDetector` test hands `otherModifiersDown` in by hand, so the table
/// below could name the wrong bit for a key and the whole suite would still
/// pass while ⌘+⇧+C started switching the input source. F-4 rests on these
/// constants, so they belong where a test can read them.
public enum ModifierFlags {
  /// `NX_DEVICE*KEYMASK`. These, not `.maskCommand`: the device-independent
  /// bit stays set while *either* ⌘ is held, so releasing one of two would read
  /// as "still down" and a left-then-right chord would complete as a tap.
  static let maskByKeyCode: [UInt16: UInt64] = [
    KeyCode.leftCommand: 0x0000_0008,
    KeyCode.rightCommand: 0x0000_0010,
    56: 0x0000_0002,  // left shift
    60: 0x0000_0004,  // right shift
    59: 0x0000_0001,  // left control
    62: 0x0000_2000,  // right control
    58: 0x0000_0020,  // left option
    61: 0x0000_0040,  // right option
    57: 0x0001_0000,  // caps lock (no left/right form)
    63: 0x0080_0000,  // fn (no left/right form)
  ]

  static let all: UInt64 = maskByKeyCode.values.reduce(0, |)

  /// Reads `flags` from the point of view of the key that changed.
  ///
  /// A key code with no bit in the table reads as up with nothing else held,
  /// which cancels a pending press. That is the safe direction: the alternative
  /// is a key whose release we cannot see leaving the detector armed for good.
  public static func state(
    keyCode: UInt16, flags: UInt64
  ) -> (isDown: Bool, otherModifiersDown: Bool) {
    let own = maskByKeyCode[keyCode] ?? 0
    return (
      isDown: flags & own != 0,
      otherModifiersDown: flags & all & ~own != 0
    )
  }

  /// The detector's view of a modifier event.
  public static func detectorKind(keyCode: UInt16, flags: UInt64) -> DetectorEvent.Kind {
    let state = state(keyCode: keyCode, flags: flags)
    return .modifier(
      keyCode: keyCode, isDown: state.isDown, otherModifiersDown: state.otherModifiersDown)
  }
}
