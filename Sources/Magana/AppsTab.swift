// AppsTab.swift
// Settings › 個別: the per-app table (F-8, F-17) and the sheet that adds to it.

import AppKit
import MaganaCore
import SwiftUI

struct AppsTab: View {
  @ObservedObject var controller: AppController
  @State private var isAddingApp = false
  /// Looked up once per rule rather than on every redraw: resolving a bundle
  /// identifier to an icon goes through LaunchServices.
  @State private var icons: [String: NSImage] = [:]

  var body: some View {
    SettingsPage {
      HStack {
        Text("アプリごとの設定")
          .font(SettingsChrome.rowTitleFont.weight(.semibold))
          .foregroundStyle(SettingsChrome.primaryText)
        Spacer()
        Button("＋ 実行中のアプリから追加") { isAddingApp = true }
          .buttonStyle(.borderedProminent)
      }

      if controller.settings.appRules.isEmpty {
        SettingsCard {
          VStack(alignment: .leading, spacing: 6) {
            Text("アプリごとの設定はありません")
              .font(SettingsChrome.rowTitleFont.weight(.semibold))
              .foregroundStyle(SettingsChrome.primaryText)
            Text(
              "仮想マシンやリモートデスクトップなど ⌘ をそのまま渡したいアプリや、前面になったら英数 / かなにしたいアプリを追加します"
            )
            .font(SettingsChrome.rowCaptionFont)
            .foregroundStyle(SettingsChrome.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(SettingsChrome.rowHorizontalPadding)
        }
      } else {
        SettingsCard {
          ForEach(Array(controller.settings.appRules.enumerated()), id: \.element.id) {
            index, rule in
            if index > 0 { SettingsRowDivider() }
            AppRuleRow(controller: controller, rule: rule, icon: icons[rule.bundleID])
          }
        }
      }
    }
    .sheet(isPresented: $isAddingApp) {
      AddAppSheet(controller: controller, isPresented: $isAddingApp)
    }
    .onAppear { loadIcons() }
    .onChange(of: controller.settings.appRules) { loadIcons() }
  }

  private func loadIcons() {
    for rule in controller.settings.appRules where icons[rule.bundleID] == nil {
      icons[rule.bundleID] = AppRuleService.icon(forBundleID: rule.bundleID)
    }
  }
}

private struct AppRuleRow: View {
  @ObservedObject var controller: AppController
  let rule: AppRule
  let icon: NSImage?
  @State private var isHoveringRemove = false

  var body: some View {
    HStack(spacing: 10) {
      AppIcon(image: icon)
      Text(rule.displayName)
        .font(SettingsChrome.rowTitleFont)
        .foregroundStyle(SettingsChrome.primaryText)
        .lineLimit(1)
      Spacer(minLength: 8)
      Picker("", selection: ruleBinding) {
        ForEach(AppRuleAction.allCases, id: \.self) { Text(label(for: $0)).tag($0) }
      }
      .labelsHidden()
      .accessibilityLabel("\(rule.displayName) の切り替え動作")
      .frame(width: 130)
      Button {
        controller.removeRule(rule)
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 13))
          .foregroundStyle(isHoveringRemove ? Color.red : SettingsChrome.secondaryText)
      }
      .buttonStyle(.plain)
      .onHover { isHoveringRemove = $0 }
      .accessibilityLabel("\(rule.displayName) を外す")
    }
    .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
    .padding(.vertical, 10)
  }

  private var ruleBinding: Binding<AppRuleAction> {
    Binding(
      get: { controller.settings.rule(forBundleID: rule.bundleID)?.action ?? rule.action },
      set: { controller.setRuleAction($0, for: rule) })
  }
}

/// An app's icon, or a placeholder for one that is no longer installed — a
/// rule outlives the app it names, so the row has to draw without.
private struct AppIcon: View {
  let image: NSImage?

  var body: some View {
    Group {
      if let image {
        Image(nsImage: image).resizable()
      } else {
        Image(systemName: "app.dashed")
          .resizable()
          .foregroundStyle(SettingsChrome.secondaryText)
      }
    }
    .frame(width: 20, height: 20)
  }
}

private struct AddAppSheet: View {
  @ObservedObject var controller: AppController
  @Binding var isPresented: Bool
  /// Snapshotted once. Re-reading the running apps on every redraw would let a
  /// row move out from under the pointer as other apps launch and quit.
  @State private var apps: [RunningApp] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("実行中のアプリから選ぶ").font(.headline)
        Spacer()
        Button("キャンセル") { isPresented = false }
      }
      List(apps) { app in
        HStack(spacing: 10) {
          AppIcon(image: app.icon)
          Text(app.name).font(SettingsChrome.rowTitleFont)
          Spacer(minLength: 8)
          Button("追加") {
            controller.addRule(for: app)
            isPresented = false
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .frame(height: 280)
    }
    .padding(16)
    .frame(width: 380)
    .onAppear { apps = controller.runningApplications() }
  }
}
