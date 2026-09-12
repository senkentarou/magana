// PermissionService.swift
// Knows whether Accessibility is granted, and asks for it.

import AppKit
import ApplicationServices

/// Watches the one permission this app needs.
///
/// Polling rather than waiting for a notification because macOS does not send
/// one: a grant made in System Settings reaches a running process only when it
/// next asks. One `AXIsProcessTrusted()` call per second is far below the CPU
/// budget, and it is what makes both directions work — the app
/// coming alive within the three seconds F-5 promises, and it noticing that the
/// grant was taken away.
@MainActor
final class PermissionService {
  private(set) var isTrusted = false
  var onChange: ((Bool) -> Void)?

  /// One second, not the three the retry could take: F-5's
  /// acceptance is "enabled within three seconds of granting", and a three
  /// second period spends the whole budget on the poll alone.
  private static let pollInterval: TimeInterval = 1

  /// Held, not read. `RunLoop.add` retains the timer too, but the poll is what
  /// notices a grant being given or taken away, so its lifetime is not left to
  /// the run loop alone.
  private var timer: Timer?

  func start() {
    isTrusted = AXIsProcessTrusted()
    let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { _ in
      MainActor.assumeIsolated { [weak self] in self?.poll() }
    }
    // .common so the poll keeps running while a menu is open.
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  /// Shows the system prompt and opens the Accessibility pane.
  ///
  /// Both, because they do different jobs: the prompt is what puts Magana into
  /// the list at all (macOS shows it at most once per app), and the pane is
  /// where the user turns the switch on.
  func requestAndOpenSettings() {
    // The literal, not `kAXTrustedCheckOptionPrompt`: that symbol is imported
    // as a global `var`, which Swift 6 will not let a concurrent context read.
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }

  private func poll() {
    let trusted = AXIsProcessTrusted()
    guard trusted != isTrusted else { return }
    isTrusted = trusted
    onChange?(trusted)
  }
}
