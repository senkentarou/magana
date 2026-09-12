// ModifierFlagsTests.swift
// Verifies that the modifier bit table reads a real flag word the way
// AloneDetector assumes it does — the half of F-4 that no test used to cover.

import Testing

@testable import MaganaCore

@Suite("Modifier flags")
struct ModifierFlagsTests {

  /// The bits macOS actually sets, as a lookup for the tests below.
  private static let bits: [(name: String, keyCode: UInt16, mask: UInt64)] = [
    ("left ⌘", KeyCode.leftCommand, 0x0000_0008),
    ("right ⌘", KeyCode.rightCommand, 0x0000_0010),
    ("left ⇧", 56, 0x0000_0002),
    ("right ⇧", 60, 0x0000_0004),
    ("left ⌃", 59, 0x0000_0001),
    ("right ⌃", 62, 0x0000_2000),
    ("left ⌥", 58, 0x0000_0020),
    ("right ⌥", 61, 0x0000_0040),
    ("caps lock", 57, 0x0001_0000),
    ("fn", 63, 0x0080_0000),
  ]

  @Test("Every modifier reads as down when, and only when, its own bit is set")
  func ownBit() {
    for entry in Self.bits {
      let down = ModifierFlags.state(keyCode: entry.keyCode, flags: entry.mask)
      #expect(down.isDown, "\(entry.name) should read as down")
      #expect(!down.otherModifiersDown, "\(entry.name) alone is not other modifiers")

      let up = ModifierFlags.state(keyCode: entry.keyCode, flags: 0)
      #expect(!up.isDown, "\(entry.name) should read as up")
    }
  }

  @Test("No two modifiers share a bit")
  func distinctBits() {
    // A duplicated constant would make one key's release look like the other's,
    // and the detector would arm or cancel on the wrong event.
    let masks = Self.bits.map(\.mask)
    #expect(Set(masks).count == masks.count)
  }

  @Test("Anything held alongside the key reads as another modifier")
  func otherModifiers() {
    for entry in Self.bits {
      for other in Self.bits where other.keyCode != entry.keyCode {
        let state = ModifierFlags.state(
          keyCode: entry.keyCode, flags: entry.mask | other.mask)
        #expect(state.isDown, "\(entry.name) is still down")
        #expect(
          state.otherModifiersDown,
          "\(other.name) held with \(entry.name) must read as another modifier")
      }
    }
  }

  @Test("The two ⌘ keys do not read as each other (F-3)")
  func commandKeysAreIndependent() {
    // The device-independent .maskCommand bit stays set while either ⌘ is held.
    // If the table used it, releasing one of two would still read as down and
    // a left-then-right chord would complete as a tap.
    let both = ModifierFlags.state(
      keyCode: KeyCode.leftCommand, flags: 0x0000_0008 | 0x0000_0010)
    #expect(both.isDown)
    #expect(both.otherModifiersDown, "the other ⌘ counts as another modifier")

    let rightOnly = ModifierFlags.state(keyCode: KeyCode.leftCommand, flags: 0x0000_0010)
    #expect(!rightOnly.isDown, "left ⌘ is up when only the right bit is set")
  }

  @Test("A key code the table does not know reads as up")
  func unknownKeyCode() {
    // Safe direction: an unrecognised modifier cancels a pending press rather
    // than leaving the detector armed against a release it will never see.
    let state = ModifierFlags.state(keyCode: 0xFF, flags: 0x0000_0008)
    #expect(!state.isDown)
    #expect(state.otherModifiersDown, "the ⌘ that is down is still someone else")
  }

  @Test("⌘+⇧ does not complete as an alone press (F-4)")
  func commandWithShiftDoesNotSwitch() {
    // The end-to-end shape: real flag words in, no switch out.
    var detector = AloneDetector(
      configuration: DetectorConfiguration(
        leftAction: .eisuu, rightAction: .kana, aloneTimeout: 1))

    let shiftBit: UInt64 = 0x0000_0002
    let leftCommandBit: UInt64 = 0x0000_0008

    _ = detector.handle(
      DetectorEvent(
        kind: ModifierFlags.detectorKind(keyCode: 56, flags: shiftBit), timestamp: 0))
    _ = detector.handle(
      DetectorEvent(
        kind: ModifierFlags.detectorKind(
          keyCode: KeyCode.leftCommand, flags: shiftBit | leftCommandBit),
        timestamp: 0.01))
    let onRelease = detector.handle(
      DetectorEvent(
        kind: ModifierFlags.detectorKind(keyCode: KeyCode.leftCommand, flags: shiftBit),
        timestamp: 0.02))

    #expect(onRelease == nil)
  }
}
