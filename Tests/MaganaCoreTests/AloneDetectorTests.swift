// AloneDetectorTests.swift
// Verifies which ⌘ presses switch the input source and, more importantly, which
// ones must not (F-1 to F-4).

import Testing

@testable import MaganaCore

private let timeout: Double = 1.0

private func makeDetector(
  left: KeyAction = .eisuu,
  right: KeyAction = .kana
) -> AloneDetector {
  AloneDetector(
    configuration: DetectorConfiguration(
      leftAction: left, rightAction: right, aloneTimeout: timeout))
}

private func modifier(
  _ keyCode: UInt16,
  down: Bool,
  at t: Double,
  others: Bool = false
) -> DetectorEvent {
  DetectorEvent(
    kind: .modifier(keyCode: keyCode, isDown: down, otherModifiersDown: others), timestamp: t)
}

@Suite("Alone press detection")
struct AloneDetectorTests {

  @Test("Left ⌘ tapped alone asks for 英数")
  func leftAlone() {
    var detector = makeDetector()
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0)) == nil)
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.08)) == .eisuu)
  }

  @Test("Right ⌘ tapped alone asks for かな")
  func rightAlone() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.rightCommand, down: true, at: 0))
    #expect(detector.handle(modifier(KeyCode.rightCommand, down: false, at: 0.08)) == .kana)
  }

  @Test("Swapping the sides swaps the actions (F-12)")
  func swappedSides() {
    var detector = makeDetector(left: .kana, right: .eisuu)
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.05)) == .kana)
  }

  @Test("A side set to 何もしない stays silent (F-12)")
  func sideDisabled() {
    var detector = makeDetector(left: .none)
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.05)) == nil)
  }

  @Test("⌘+C does not switch (F-4)")
  func commandWithKey() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
    _ = detector.handle(DetectorEvent(kind: .key, timestamp: 0.02))
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.06)) == nil)
  }

  @Test("⌘+click does not switch (F-4)")
  func commandWithMouse() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.rightCommand, down: true, at: 0))
    _ = detector.handle(DetectorEvent(kind: .mouse, timestamp: 0.03))
    #expect(detector.handle(modifier(KeyCode.rightCommand, down: false, at: 0.09)) == nil)
  }

  @Test("⌘+scroll does not switch (F-4)")
  func commandWithScroll() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.rightCommand, down: true, at: 0))
    _ = detector.handle(DetectorEvent(kind: .scroll, timestamp: 0.03))
    #expect(detector.handle(modifier(KeyCode.rightCommand, down: false, at: 0.09)) == nil)
  }

  @Test("Holding past the timeout does not switch (F-3)")
  func heldTooLong() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: timeout)) == nil)
  }

  @Test("Released a hair under the timeout still switches (F-3 boundary)")
  func justUnderTimeout() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
    #expect(
      detector.handle(modifier(KeyCode.leftCommand, down: false, at: timeout - 0.001)) == .eisuu)
  }

  @Test("⇧ held first makes the following ⌘ a modifier (F-3)")
  func otherModifierFirst() {
    var detector = makeDetector()
    _ = detector.handle(modifier(56, down: true, at: 0))  // shift
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0.01, others: true))
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.05)) == nil)
  }

  @Test("⇧ pressed while ⌘ is held cancels the tap (F-3)")
  func otherModifierDuring() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
    _ = detector.handle(modifier(56, down: true, at: 0.02, others: true))
    _ = detector.handle(modifier(56, down: false, at: 0.04, others: true))
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.06)) == nil)
  }

  @Test("Both ⌘ held: neither fires, whichever is released first")
  func bothCommands() {
    for releaseLeftFirst in [true, false] {
      var detector = makeDetector()
      _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
      _ = detector.handle(modifier(KeyCode.rightCommand, down: true, at: 0.02, others: true))
      let first = releaseLeftFirst ? KeyCode.leftCommand : KeyCode.rightCommand
      let second = releaseLeftFirst ? KeyCode.rightCommand : KeyCode.leftCommand
      #expect(detector.handle(modifier(first, down: false, at: 0.05)) == nil)
      #expect(detector.handle(modifier(second, down: false, at: 0.07)) == nil)
    }
  }

  @Test("A cancelled press does not poison the next one")
  func recoversAfterCancel() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
    _ = detector.handle(DetectorEvent(kind: .key, timestamp: 0.01))
    _ = detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.05))
    _ = detector.handle(modifier(KeyCode.rightCommand, down: true, at: 0.5))
    #expect(detector.handle(modifier(KeyCode.rightCommand, down: false, at: 0.55)) == .kana)
  }

  @Test("reset() drops a press that started before the tap was watching")
  func resetDropsCandidate() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0))
    detector.reset()
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.05)) == nil)
  }

  @Test("A ⌘ that goes down while another modifier is held is a modifier (F-3)")
  func commandWhileAnotherModifierHeld() {
    var detector = makeDetector()
    _ = detector.handle(modifier(KeyCode.leftCommand, down: true, at: 0, others: true))
    #expect(detector.handle(modifier(KeyCode.leftCommand, down: false, at: 0.05)) == nil)
  }
}
