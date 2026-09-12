// CreditsTab.swift
// Settings › クレジット: the version, the licence and where the source lives.

import MaganaCore
import SwiftUI

/// Who made this, and which build it is.
///
/// The only tab that sets nothing — and the only one with nothing to press:
/// checking for updates lives in the menu. It drops
/// the cards and rows the others are built from, since a bordered box around
/// four lines of text would read as a group of settings whose controls failed
/// to draw. One centred column instead, the shape macOS gives its About panel.
struct CreditsTab: View {
  private static let repositoryURL = URL(string: "https://github.com/senkentarou/magana")!

  var body: some View {
    VStack(spacing: 16) {
      Spacer()
      if let icon = NSApp.applicationIconImage {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 72, height: 72)
      }
      Text("Magana")
        .font(.title)
        .fontWeight(.bold)
      Text("バージョン \(AppVersion.short)")
        .foregroundStyle(.secondary)
      // English in the Japanese UI as well: a copyright notice is a canonical
      // form rather than a sentence to the user, and macOS leaves its own
      // untranslated for the same reason. Set smaller and dimmer than the
      // version: it is the fine print, not the headline.
      Text(verbatim: "© 2026 Masahiro Senda · Licensed under GPL-3.0")
        .font(.caption)
        .foregroundStyle(.secondary)
      Link("github.com/senkentarou/magana", destination: Self.repositoryURL)
        .font(.caption)
      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(SettingsChrome.background)
  }
}

enum AppVersion {
  static let short =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
}
