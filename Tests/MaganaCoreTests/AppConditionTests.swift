// AppConditionTests.swift
// Verifies the priority the menu's status line follows and which warnings
// appear together.

import Testing

@testable import MaganaCore

@Suite("App condition")
struct AppConditionTests {

  private func condition(
    isTrusted: Bool = true,
    paused: Bool = false,
    disableOnJIS: Bool = true,
    hasJISKeyboard: Bool = false,
    hasJapaneseSource: Bool = true
  ) -> AppCondition {
    AppCondition(
      isTrusted: isTrusted,
      paused: paused,
      disableOnJIS: disableOnJIS,
      hasJISKeyboard: hasJISKeyboard,
      hasJapaneseSource: hasJapaneseSource
    )
  }

  @Test("Nothing wrong means active")
  func active() {
    #expect(condition().status == .active)
    #expect(condition().canSwitch)
    #expect(condition().warnings.isEmpty)
  }

  @Test("Missing permission outranks everything else")
  func permissionWins() {
    // Without the grant there is no tap, so a pause or a JIS keyboard is not
    // the thing to tell the user about.
    let everything = condition(
      isTrusted: false, paused: true, hasJISKeyboard: true, hasJapaneseSource: false)
    #expect(everything.status == .noPermission)
    #expect(!everything.canSwitch)
  }

  @Test("A pause the user asked for outranks the JIS stand-down")
  func pauseWins() {
    #expect(condition(paused: true, hasJISKeyboard: true).status == .paused)
  }

  @Test("A JIS keyboard only stands the switch down while the setting is on")
  func jisRespectsTheSetting() {
    #expect(condition(hasJISKeyboard: true).status == .disabledByJISKeyboard)
    #expect(condition(disableOnJIS: false, hasJISKeyboard: true).status == .active)
    #expect(condition(disableOnJIS: false, hasJISKeyboard: true).canSwitch)
  }

  @Test("Warnings are not exclusive with each other")
  func warningsStack() {
    // The permission can be missing while there is also no Japanese input
    // source, and the user needs to be told both.
    let both = condition(isTrusted: false, hasJapaneseSource: false)
    #expect(both.warnings == [.permissionMissing, .noJapaneseInputSource])
  }

  @Test("A missing Japanese input source warns even while everything works")
  func noJapaneseSource() {
    let condition = condition(hasJapaneseSource: false)
    #expect(condition.status == .active, "英数 still works, so the app is not disabled")
    #expect(condition.warnings == [.noJapaneseInputSource])
  }

  @Test("The JIS warning follows the JIS status")
  func jisWarning() {
    #expect(condition(hasJISKeyboard: true).warnings == [.jisKeyboardConnected])
    #expect(condition(disableOnJIS: false, hasJISKeyboard: true).warnings.isEmpty)
  }
}

@Suite("Switch decision")
struct SwitchDecisionTests {

  @Test("Posting is skipped when the input source is already the target (F-1, F-2)")
  func idempotent() {
    #expect(
      SwitchDecision.outcome(target: .eisuu, current: .eisuu, hasJapaneseSource: true)
        == .alreadyThere)
    #expect(
      SwitchDecision.outcome(target: .kana, current: .kana, hasJapaneseSource: true)
        == .alreadyThere)
  }

  @Test("かな with no Japanese input source posts nothing")
  func kanaWithoutJapanese() {
    #expect(
      SwitchDecision.outcome(target: .kana, current: .eisuu, hasJapaneseSource: false)
        == .noJapaneseInputSource)
  }

  @Test("英数 works with no Japanese input source")
  func eisuuWithoutJapanese() {
    // ABC is always there to go back to, so losing the IME must not strand the
    // user in かな with no way out.
    #expect(
      SwitchDecision.outcome(target: .eisuu, current: .kana, hasJapaneseSource: false)
        == .post)
  }

  @Test("A real change posts")
  func posts() {
    #expect(
      SwitchDecision.outcome(target: .kana, current: .eisuu, hasJapaneseSource: true)
        == .post)
  }
}

@Suite("Held ⌘ keys")
struct HeldCommandKeysTests {

  private func modifier(_ keyCode: UInt16, isDown: Bool) -> DetectorEvent {
    DetectorEvent(
      kind: .modifier(keyCode: keyCode, isDown: isDown, otherModifiersDown: false),
      timestamp: 0)
  }

  @Test("Each ⌘ lights and clears on its own")
  func tracksBothSides() {
    var held = HeldCommandKeys()
    held.handle(modifier(KeyCode.leftCommand, isDown: true))
    #expect(held.sides == [.left])

    held.handle(modifier(KeyCode.rightCommand, isDown: true))
    #expect(held.sides == [.left, .right])

    held.handle(modifier(KeyCode.leftCommand, isDown: false))
    #expect(held.sides == [.right])
  }

  @Test("A key that is not a ⌘ changes nothing")
  func ignoresOtherKeys() {
    var held = HeldCommandKeys()
    held.handle(modifier(56, isDown: true))  // left shift
    held.handle(DetectorEvent(kind: .key, timestamp: 0))
    held.handle(DetectorEvent(kind: .mouse, timestamp: 0))
    #expect(held.sides.isEmpty)
  }

  @Test("Reset clears a cap that would otherwise stay lit")
  func reset() {
    // A ⌘ released while the tap was stopped never sends its key-up.
    var held = HeldCommandKeys()
    held.handle(modifier(KeyCode.leftCommand, isDown: true))
    held.reset()
    #expect(held.sides.isEmpty)
  }
}
