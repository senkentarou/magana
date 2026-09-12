// CommandSideTests.swift
// Verifies that only the two ⌘ key codes name a side, so the settings window's
// key caps cannot be lit by any other key.

import Testing

@testable import MaganaCore

@Suite("Command side")
struct CommandSideTests {

  @Test("The two ⌘ key codes name their own side")
  func commandKeyCodes() {
    #expect(CommandSide(keyCode: KeyCode.leftCommand) == .left)
    #expect(CommandSide(keyCode: KeyCode.rightCommand) == .right)
  }

  @Test("Every other key code names no side")
  func otherKeyCodes() {
    // ⌥ / ⇧ / ⌃ / fn, the modifiers that sit next to ⌘, and a plain letter.
    for keyCode: UInt16 in [58, 61, 56, 60, 59, 62, 63, 8] {
      #expect(CommandSide(keyCode: keyCode) == nil)
    }
  }
}
