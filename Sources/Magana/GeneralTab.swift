// GeneralTab.swift
// Settings › 一般: the switches, the tap timeout, the accessibility state and
// the two ⌘ key caps.
//
// Its own file because it is the tab that changes. Every fix to the key caps
// (f06d806, f79871f, ff43ac6, 39226ed) touched this tab and nothing else, but
// the diff had to be read against the other two tabs to see that.

import MaganaCore
import SwiftUI

/// The settings window's size, kept next to the tab it is measured from.
///
/// It lived in `SettingsChrome` among the values every tab shares, but it is
/// not one of them: both times it changed (4b8b61e, f06d806) the reason was a
/// row added or resized on this tab, and every one of the numbers below is a
/// 一般 row. Changing this tab and the number it implies is now one file.
enum SettingsWindow {
  /// The window's fixed size. Fixed rather than fitted so switching tabs never
  /// resizes the window out from under the pointer, and tall enough
  /// that the general tab — the tallest of the three fixed layouts — does not
  /// scroll. A settings window with a scroll bar hides the rest of itself from
  /// someone who has no reason to suspect there is more.
  ///
  /// The height is the general tab added up, from the measured heights of the
  /// controls macOS draws: tab bar 66 (50 + 8 twice), page padding 40, the
  /// settings card 203 (two switch rows at 46, the stacked slider row at 68,
  /// the accessibility row at 40, three hairlines), card spacing 16, and the ⌘
  /// card 138 (padding 32, heading 16, key caps 46, menus 20, two 12pt gaps)
  /// = 463. The remaining few points are slack for a font that measures
  /// differently.
  static let size = CGSize(width: 480, height: 469)
}

struct GeneralTab: View {
  @ObservedObject var controller: AppController

  var body: some View {
    SettingsPage {
      SettingsCard {
        SettingsRow(title: "ログイン時に起動") {
          Toggle(
            "",
            isOn: Binding(
              get: { controller.settings.launchAtLogin },
              set: { controller.setLaunchAtLogin($0) })
          )
          .labelsHidden()
          .toggleStyle(.switch)
          .accessibilityLabel("ログイン時に起動")
        }
        SettingsRowDivider()
        SettingsRow(title: "JIS キーボードでは無効にする") {
          Toggle("", isOn: binding(\.disableOnJIS)).labelsHidden().toggleStyle(.switch)
            .accessibilityLabel("JIS キーボードでは無効にする")
        }
        SettingsRowDivider()
        TimeoutRow(milliseconds: binding(\.aloneTimeoutMilliseconds))
        SettingsRowDivider()
        AccessibilityRow(controller: controller)
      }

      SettingsCard {
        CommandKeyCard(
          left: binding(\.leftAction),
          right: binding(\.rightAction),
          monitor: controller.commandKeys)
      }
    }
  }

  private func binding<Value>(
    _ keyPath: WritableKeyPath<MaganaCore.Settings, Value>
  ) -> Binding<Value> {
    Binding(
      get: { controller.settings[keyPath: keyPath] },
      set: { controller.settings[keyPath: keyPath] = $0 })
  }

  /// No clamp here. `Settings` decodes the timeout into its own range, so a
  /// blob from outside it can no longer reach the slider — and clamping only
  /// what is displayed is what let the window show 200ms while the detector
  /// ran on the stored number.
}

/// The tap timeout, as a slider carrying its current value.
///
/// A slider rather than a number field: this is a value you find by feel, and
/// a field asks you to leave the keyboard's own timing to type three digits
/// and confirm them before anything changes.
private struct TimeoutRow: View {
  @Binding var milliseconds: Int

  private static let range = MaganaCore.Settings.aloneTimeoutRange
  /// 100ms is the smallest step that is felt rather than measured.
  private static let step = 100

  var body: some View {
    SettingsStackedRow(title: "キー入力のタイムアウト") {
      HStack(spacing: 12) {
        // No `step:`. Passing one makes macOS draw a tick for every stop, and
        // eighteen ticks under a thumb read as a ruler rather than a setting.
        // The 100ms grid is kept by rounding on write instead.
        Slider(
          value: Binding(
            get: { Double(milliseconds) },
            set: { milliseconds = Int(($0 / Double(Self.step)).rounded()) * Self.step }),
          in: Double(Self.range.lowerBound)...Double(Self.range.upperBound)
        )
        .labelsHidden()
        .accessibilityLabel("キー入力のタイムアウト")

        // Monospaced digits and a floor on the width so the number does not
        // jitter the slider as it runs from 200 to 2,000.
        Text("\(milliseconds) ms")
          .font(SettingsChrome.rowCaptionFont)
          .foregroundStyle(SettingsChrome.secondaryText)
          .monospacedDigit()
          .frame(minWidth: 62, alignment: .trailing)
      }
    }
  }
}

/// The permission state, and the steps to fix it without leaving the window.
///
/// The first-launch permission window (F-5) stays as it is; this row is for
/// someone who is already in settings, for whom another window opening is one
/// more place to be.
private struct AccessibilityRow: View {
  @ObservedObject var controller: AppController
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // The press is on the row, not on the chevron. A hit area the size of a
      // ∨ has to be aimed at, and the row carries nothing else to press, so
      // there is no second target to lose by taking the whole width.
      Button {
        isExpanded.toggle()
      } label: {
        SettingsRow(title: "アクセシビリティ") {
          HStack(spacing: 8) {
            Label(
              controller.isTrusted ? "許可済み" : "未許可",
              systemImage: controller.isTrusted
                ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
            )
            .font(SettingsChrome.rowCaptionFont)
            .foregroundStyle(controller.isTrusted ? Color.green : Color.red)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(SettingsChrome.secondaryText)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      // Spelled out rather than left to the label SwiftUI builds from the row's
      // text, so the state stays a value and the press stays a hint.
      .accessibilityLabel("アクセシビリティ")
      .accessibilityValue(controller.isTrusted ? "許可済み" : "未許可")
      .accessibilityHint(isExpanded ? "手順を閉じる" : "手順を開く")

      if isExpanded {
        VStack(alignment: .leading, spacing: 8) {
          if !controller.isTrusted {
            Text("アクセシビリティが許可されていないため、切替は動いていません。システム設定でオンにすると自動で有効になります")
              .font(SettingsChrome.rowCaptionFont)
              .foregroundStyle(Color.red)
              .fixedSize(horizontal: false, vertical: true)
          }
          Text("左右⌘の押下を検知して英数 / かなキーを送信するために利用します")
            .font(SettingsChrome.rowCaptionFont)
            .foregroundStyle(SettingsChrome.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
          Button("システム設定を開く") { controller.openAccessibilitySettings() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
        .padding(.bottom, SettingsChrome.rowVerticalPadding)
      }
    }
  }
}

/// The two ⌘ keys, each over the menu that sets it.
///
/// Only these two are drawn. The rest of the bottom row was there to say where
/// the ⌘ sit, but a key cap next to a control looks like another control, and
/// the surrounding ones could not be pressed.
///
/// Each side is one column: a 「左」/「右」 label, the cap, and the menu that
/// binds it. The column position alone was meant to say which ⌘ is which, but
/// it did not read on the machine, so the label went in beside the cap rather
/// than back onto the menus, which would say the same thing twice.
private struct CommandKeyCard: View {
  @Binding var left: KeyAction
  @Binding var right: KeyAction
  @ObservedObject var monitor: CommandKeyMonitor

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("左右の ⌘ に割り当てる")
        .font(SettingsChrome.rowTitleFont.weight(.semibold))
        .foregroundStyle(SettingsChrome.primaryText)

      HStack(alignment: .top, spacing: 16) {
        column("左", side: .left, selection: $left)
        column("右", side: .right, selection: $right)
      }
    }
    .padding(SettingsChrome.rowHorizontalPadding)
  }

  private func column(_ name: String, side: CommandSide, selection: Binding<KeyAction>)
    -> some View
  {
    VStack(spacing: 12) {
      HStack(spacing: 8) {
        Text(name)
          .font(SettingsChrome.rowCaptionFont)
          .foregroundStyle(SettingsChrome.secondaryText)
        CommandCap(action: selection.wrappedValue, isHeld: monitor.held.contains(side))
      }

      Picker("", selection: selection) {
        ForEach(KeyAction.allCases, id: \.self) { Text(label(for: $0)).tag($0) }
      }
      .labelsHidden()
      .accessibilityLabel("\(name) ⌘ を押して離したとき")
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity)
  }
}

/// One of the two keys this screen sets, drawn at the size and shape of the
/// real cap: 56 × 46, a rounded top face over a front edge, with what the key
/// does written under the glyph the way a Mac ⌘ carries "command".
///
/// At rest it is an unlit key — the legend in the text colour, the face in the
/// page background. It goes blue while that ⌘ is actually held, so pressing the
/// key you are looking at shows you which cap it is.
/// A key with nothing bound lights grey instead: it is being pressed, but the
/// blue is what says "this is doing something".
private struct CommandCap: View {
  let action: KeyAction
  let isHeld: Bool

  private static let size = CGSize(width: 56, height: 46)
  private static let radius: CGFloat = 7
  /// The front edge of the cap: the drawn height minus the face.
  private static let edge: CGFloat = 3

  private var isBound: Bool { action != .none }
  private var isLit: Bool { isHeld && isBound }

  private var legend: Color { isLit ? Color.accentColor : SettingsChrome.primaryText }
  private var face: Color {
    if isLit { return Color.accentColor.opacity(0.16) }
    if isHeld { return SettingsChrome.border }
    return SettingsChrome.background
  }
  private var edgeTint: Color {
    isLit ? Color.accentColor.opacity(0.55) : SettingsChrome.border
  }

  var body: some View {
    VStack(spacing: 1) {
      Text("⌘").font(.system(size: 14, weight: .medium))
      Text(shortLabel(for: action)).font(.system(size: 10, weight: .semibold))
    }
    .foregroundStyle(legend)
    .frame(width: Self.size.width, height: Self.size.height)
    .background(RoundedRectangle(cornerRadius: Self.radius).fill(face))
    .overlay(alignment: .bottom) {
      // The cap is lit from above, so its front edge reads as the one face in
      // shadow. Drawn as a strip rather than a thicker border so the top three
      // sides stay hairlines.
      RoundedRectangle(cornerRadius: Self.radius)
        .fill(edgeTint)
        .frame(height: Self.radius + Self.edge)
        .mask(alignment: .bottom) { Rectangle().frame(height: Self.edge) }
    }
    .overlay(
      RoundedRectangle(cornerRadius: Self.radius)
        .stroke(isLit ? Color.accentColor.opacity(0.6) : SettingsChrome.border, lineWidth: 1)
    )
    // Held down the cap sits a shade lower, the way a real one does.
    .offset(y: isHeld ? 1 : 0)
    .animation(.easeOut(duration: 0.08), value: isHeld)
    .accessibilityLabel(isHeld ? "⌘ を押しています" : "⌘")
  }
}
