// PermissionView.swift
// First launch, and every time the grant goes away. Wording from

import SwiftUI

struct PermissionView: View {
  @ObservedObject var controller: AppController
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("アクセシビリティの許可が必要です")
          .font(.title2.weight(.semibold))
        Text(
          "左右の ⌘ を押して離したことを検知して英数 / かなキーを送るために、macOS のアクセシビリティ権限を使います。⌘ 以外のキーの内容は記録も送信もしません。"
        )
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("1. 「システム設定を開く」を押す")
        Text("2. プライバシーとセキュリティ › アクセシビリティ で Magana をオンにする")
        Text("3. この画面に戻ると 3 秒以内に自動で有効になる")
      }
      .font(.callout)

      if controller.isTrusted {
        Banner(
          text: "有効になりました。左 ⌘ で英数、右 ⌘ でかなに切り替わります",
          tint: .green)
      } else {
        Banner(
          text:
            "アクセシビリティが許可されていません。システム設定でオンにすると自動で有効になります",
          tint: .red)
      }

      if controller.isTrusted {
        Button("閉じる") { dismiss() }
          .keyboardShortcut(.defaultAction)
          .controlSize(.large)
          .frame(maxWidth: .infinity)
      } else {
        Button("システム設定を開く") { controller.openAccessibilitySettings() }
          .keyboardShortcut(.defaultAction)
          .controlSize(.large)
          .frame(maxWidth: .infinity)
      }

      if !controller.isTrusted {
        Button("あとで（許可するまで切替は動きません）") { dismiss() }
          .buttonStyle(.link)
      }
    }
    .padding(24)
    .frame(width: 460)
  }
}

private struct Banner: View {
  let text: String
  let tint: Color

  var body: some View {
    Text(text)
      .font(.callout)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(10)
      .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.35)))
  }
}
