// SettingsTests.swift
// Verifies the ⌘ bindings the switcher reads and the settings window shows.

import Testing

@testable import MaganaCore

@Suite("What a ⌘ side is bound to")
struct SettingsSideTests {

  @Test("The default binding is 英数 on the left and かな on the right")
  func defaultBinding() {
    // The whole product in one line: this is what someone gets before they
    // open the settings window at all (F-1, F-2).
    #expect(Settings.default.leftAction == .eisuu)
    #expect(Settings.default.rightAction == .kana)
  }

  @Test("A side can be left unbound (F-12)")
  func unbound() {
    var settings = Settings.default
    settings.rightAction = .none
    #expect(settings.rightAction == KeyAction.none)

    var detector = AloneDetector(configuration: DetectorConfiguration(settings: settings))
    _ = detector.handle(
      DetectorEvent(
        kind: .modifier(keyCode: KeyCode.rightCommand, isDown: true, otherModifiersDown: false),
        timestamp: 0))
    let action = detector.handle(
      DetectorEvent(
        kind: .modifier(keyCode: KeyCode.rightCommand, isDown: false, otherModifiersDown: false),
        timestamp: 0.05))
    #expect(action == nil, "an unbound side posts nothing")
  }
}
