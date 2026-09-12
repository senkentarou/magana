// AppRuleService.swift
// Knows which app is in front and when that changes (F-8, F-17).

import AppKit

/// One running application, as the settings window's "add" list shows it.
///
/// Identity is the bundle identifier alone: the icon is a fresh `NSImage` on
/// every read, and comparing those would make the same app look like two.
struct RunningApp: Identifiable, Hashable {
  let bundleID: String
  let name: String
  let icon: NSImage?

  var id: String { bundleID }

  static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
    lhs.bundleID == rhs.bundleID
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(bundleID)
  }
}

/// Tracks the frontmost application.
///
/// `NSWorkspace.didActivateApplicationNotification` needs no permission of its
/// own, which is what makes the per-app default (F-17) free: it reuses the
/// posting path the ⌘ keys already use and adds no new grant to ask for.
@MainActor
final class AppRuleService {
  private(set) var frontmostBundleID: String?
  /// Called when a different application comes to the front.
  var onActivate: ((String?) -> Void)?

  /// Held, not read: releasing the token `addObserver(forName:)` returns ends
  /// the subscription, and this one lasts as long as the app.
  private var observer: (any NSObjectProtocol)?

  func start() {
    frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { notification in
      let app =
        notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      let bundleID = app?.bundleIdentifier
      MainActor.assumeIsolated { [weak self] in
        guard let self else { return }
        self.frontmostBundleID = bundleID
        self.onActivate?(bundleID)
      }
    }
  }

  /// Apps the user could plausibly want a rule for: the ones with a Dock tile.
  /// Background agents are excluded because they are never frontmost, so a rule
  /// on one could never fire.
  static func runningApplications() -> [RunningApp] {
    NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular }
      .compactMap { app in
        guard let bundleID = app.bundleIdentifier, let name = app.localizedName else { return nil }
        return RunningApp(bundleID: bundleID, name: name, icon: app.icon)
      }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  /// The icon macOS shows for an installed app, or nil once it is gone. A rule
  /// is kept when its app is uninstalled, so the row that names it
  /// has to be able to draw without one.
  static func icon(forBundleID bundleID: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
      return nil
    }
    return NSWorkspace.shared.icon(forFile: url.path)
  }
}
