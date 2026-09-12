// SettingsView.swift
// One window, three tabs. Wording and layout from

import AppKit
import MaganaCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject var controller: AppController
  @State private var tab: SettingsTab = .general

  var body: some View {
    VStack(spacing: 0) {
      SettingsTabBar(selection: $tab)

      switch tab {
      case .general: GeneralTab(controller: controller)
      case .apps: AppsTab(controller: controller)
      case .credits: CreditsTab()
      }
    }
    .frame(width: SettingsWindow.size.width, height: SettingsWindow.size.height)
  }
}
