// LoginItem.swift
// Registers the app to start at login (F-10).

import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp`.
///
/// The status is read back rather than assumed because macOS can answer
/// `.requiresApproval` — the registration is recorded but switched off in
/// System Settings — and a UI that showed the toggle as on would be lying.
@MainActor
enum LoginItem {
  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  /// Returns the status actually achieved, which may differ from what was
  /// asked for.
  @discardableResult
  static func setEnabled(_ enabled: Bool) -> SMAppService.Status {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      // Nothing to do but report the real state; the caller reflects it in the
      // toggle rather than pretending the change took.
    }
    return SMAppService.mainApp.status
  }
}
