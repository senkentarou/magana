// MaganaApp.swift
// Entry point. A menu bar item and two windows, no Dock tile.

import AppKit
import SwiftUI

@main
struct MaganaApp: App {
  @StateObject private var controller = AppController()

  var body: some Scene {
    MenuBarExtra {
      MenuContent(controller: controller, updater: controller.updater)
    } label: {
      MenuBarLabel(controller: controller)
    }
    .menuBarExtraStyle(.menu)

    Window("Magana 設定", id: WindowID.settings) {
      SettingsView(controller: controller)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)

    Window("Magana", id: WindowID.permission) {
      PermissionView(controller: controller)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)

    Window("Magana アップデート", id: WindowID.update) {
      UpdateView(updater: controller.updater)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }
}

/// The mark in the menu bar, and the app's only always-present view.
///
/// Start-up runs from here rather than an `NSApplicationDelegateAdaptor`
/// because `openWindow` is a SwiftUI environment value: the controller needs a
/// way to show the permission window, and this is the one view guaranteed to
/// exist before anything else does.
private struct MenuBarLabel: View {
  @ObservedObject var controller: AppController
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Image(nsImage: MenuBarIcon.image(paused: controller.status == .paused))
      // The only way into the app. Without a name it is an unlabelled image in
      // the menu bar, and the status it is already carrying visually — the
      // dimmed ⌘ of a pause — is carried here too.
      .accessibilityLabel("Magana · \(controller.statusText)")
      .onAppear {
        // LSUIElement already keeps the app out of the Dock; setting the policy
        // again covers launches that ignore the plist, such as from a debugger.
        NSApp.setActivationPolicy(.accessory)
        controller.openWindow = { id in openWindow(id: id) }
        controller.start()
      }
  }
}
