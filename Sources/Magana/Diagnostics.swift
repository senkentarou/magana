// Diagnostics.swift
// Opt-in tracing for the one path that cannot be covered by tests.

import Foundation
import MaganaCore
import os

/// Traces the journey from a key event to a posted 英数 / かな key.
///
/// This exists because the switching path needs a granted Accessibility
/// permission, a real keyboard and a real IME, so `swift test` can never reach
/// it — when it misbehaves on a machine, the alternative to a trace is
/// guessing. Off unless asked for:
///
///     defaults write com.senkentarou.magana debugLog -bool true
///     log stream --predicate 'subsystem == "com.senkentarou.magana"'
///
/// What is traced keeps the app's promise: modifier key codes only, and
/// every other key appears as the bare word `key` with no code and no
/// character.
enum Diagnostics {
  static let isEnabled = UserDefaults.standard.bool(forKey: "debugLog")

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "magana", category: "trace")

  static func trace(_ message: @autoclosure () -> String) {
    guard isEnabled else { return }
    let text = message()
    logger.info("\(text, privacy: .public)")
  }

  static func describe(_ event: DetectorEvent) -> String {
    switch event.kind {
    case .modifier(let keyCode, let isDown, let others):
      return "modifier code=\(keyCode) \(isDown ? "down" : "up") others=\(others)"
    case .key: return "key"
    case .mouse: return "mouse"
    case .scroll: return "scroll"
    }
  }
}
