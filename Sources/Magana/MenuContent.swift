// MenuContent.swift
// The menu bar menu.

import AppKit
import MaganaCore
import SwiftUI

struct MenuContent: View {
  @ObservedObject var controller: AppController
  @ObservedObject var updater: UpdateController

  var body: some View {
    // A disabled button rather than a bare `Label`, because the sister app's
    // own heading is an `isEnabled = false` item carrying an image.
    //
    // `.labelStyle(.titleAndIcon)` is what puts the dot on screen: a menu
    // resolves a `Label` with the title-only style, so without it SwiftUI
    // drops the icon while building the `NSMenuItem` and the item reaches
    // AppKit with `image == nil`. Removing this line loses the dot silently —
    // the build still passes and the wording is unchanged.
    Button {
    } label: {
      Label {
        Text(statusLine)
      } icon: {
        statusDot
      }
    }
    .labelStyle(.titleAndIcon)
    .disabled(true)

    ForEach(controller.warnings) { warning in
      if warning.kind == .permissionMissing {
        Button(warning.message) { controller.openPermissionWindow() }
      } else {
        Text(warning.message)
      }
    }

    if case .available(let release) = updater.phase {
      Button("新しいバージョン \(release.version.description) があります…") {
        controller.openUpdateWindow()
      }
    }

    Divider()

    Button(controller.settings.paused ? "再開" : "一時停止") { controller.togglePause() }
      .disabled(!controller.isTrusted)

    Divider()

    Button("設定…") { controller.openSettingsWindow() }
      .keyboardShortcut(",", modifiers: .command)

    // The only way to ask for an update check. It used to be a button on the
    // credits tab, which meant opening settings to reach it.
    Button("アップデートを確認…") {
      updater.check(userInitiated: true)
      controller.openUpdateWindow()
    }

    Divider()

    Button("Magana を終了") { controller.quit() }
      .keyboardShortcut("q", modifiers: .command)
  }

  /// The state word, and — when the app is in a position to know it — what the
  /// input source currently is.
  private var statusLine: String {
    controller.status == .noPermission
      ? controller.statusText
      : "\(controller.statusText) · \(controller.inputSourceText)"
  }

  /// The coloured dot in front of the state word, drawn the way the sister app
  /// draws its own so the two read as one family: an 8pt `circle.fill` as a
  /// *non-template* image, which is what keeps the menu from flattening it to
  /// the label tint.
  ///
  /// 一時停止 and the JIS disable are grey rather than red: the app is not
  /// switching because it was told not to, which is the same "not doing
  /// anything" the dimmed icon says (F-11), not a fault. Only the missing
  /// permission is amber, because that one is on the person to fix.
  private var statusDot: Image {
    let colour: NSColor
    switch controller.status {
    case .active: colour = NSColor(srgbRed: 0.45, green: 0.78, blue: 0.55, alpha: 1)
    case .noPermission: colour = NSColor(srgbRed: 0.95, green: 0.81, blue: 0.45, alpha: 1)
    case .paused, .disabledByJISKeyboard: colour = .tertiaryLabelColor
    }
    let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .regular)
      .applying(NSImage.SymbolConfiguration(hierarchicalColor: colour))
    let dot = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
      .withSymbolConfiguration(configuration)
    dot?.isTemplate = false
    return Image(nsImage: dot ?? NSImage()).renderingMode(.original)
  }
}
