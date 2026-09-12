// SettingsChrome.swift
// Shared look of the settings window: palette, metrics, and the tab bar / card
// / row building blocks every tab is assembled from.
//
// The settings screen is deliberately NOT built on SwiftUI's `Form(.grouped)`:
// grouped Form owns its own insets, header typography and separator placement,
// none of which can be pushed to the flatter card look this window wants (a
// 10pt card with a hairline border, a 13pt title over an 11pt caption, and a
// separator that stops before the card edge). Composing the card out of plain
// containers keeps all of those values in this one file.
//
// Colours are dynamic NSColors rather than asset catalog entries so they
// resolve against whichever NSAppearance the window is running under.

import AppKit
import MaganaCore
import SwiftUI

// MARK: - Tokens

enum SettingsChrome {

  // MARK: Metrics

  /// Corner radius of a settings card.
  static let cardRadius: CGFloat = 10
  /// Corner radius of a tab-bar button's tint.
  static let tabRadius: CGFloat = 10
  /// Padding inside a row, left and right.
  static let rowHorizontalPadding: CGFloat = 16
  /// Padding inside a row, top and bottom.
  static let rowVerticalPadding: CGFloat = 12
  /// Gap between a row's label block and its trailing control.
  static let rowControlSpacing: CGFloat = 16
  /// Vertical gap between cards on a page.
  static let cardSpacing: CGFloat = 16
  /// Page margin around the stack of cards.
  static let pagePadding: CGFloat = 20
  /// Size of one tab-bar button.
  static let tabSize = CGSize(width: 76, height: 50)
  /// Gap between tab-bar buttons.
  static let tabSpacing: CGFloat = 8

  // MARK: Fonts

  static let rowTitleFont = Font.system(size: 13)
  static let rowCaptionFont = Font.system(size: 11)
  static let tabLabelFont = Font.system(size: 11)

  // MARK: Palette

  /// Page background, behind the cards.
  static let background = dynamic(dark: rgb(0x1C, 0x1C, 0x1E), light: rgb(0xF2, 0xF2, 0xF7))
  /// Card fill, and the tab bar that merges with the title bar.
  static let surface = dynamic(dark: rgb(0x2C, 0x2C, 0x2E), light: rgb(0xFF, 0xFF, 0xFF))
  /// Card border and the hairline between rows.
  static let border = dynamic(dark: rgb(0x38, 0x38, 0x3A), light: rgb(0xD1, 0xD1, 0xD6))
  /// Row titles.
  static let primaryText = dynamic(dark: rgb(0xF5, 0xF5, 0xF7), light: rgb(0x1C, 0x1C, 0x1E))
  /// Row captions and unselected tabs.
  static let secondaryText = dynamic(dark: rgb(0x98, 0x98, 0x9D), light: rgb(0x8E, 0x8E, 0x93))

  /// Fill behind the selected tab.
  static var selectedTabTint: Color { Color.accentColor.opacity(0.16) }

  // MARK: Colour helpers

  /// A colour that resolves per appearance, so the window reads correctly in
  /// both themes without two asset entries.
  private static func dynamic(dark: NSColor, light: NSColor) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
      })
  }

  private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
  }
}

// MARK: - Tabs

/// The three pages of the settings window.
enum SettingsTab: String, CaseIterable, Identifiable {
  case general
  case apps
  case credits

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: return "一般"
    case .apps: return "個別"
    case .credits: return "クレジット"
    }
  }

  var symbol: String {
    switch self {
    case .general: return "gearshape"
    case .apps: return "square.grid.2x2"
    case .credits: return "info.circle"
    }
  }
}

/// Icon over label, centred under the title bar — the shape macOS gives a
/// tabbed settings window. Stretching the buttons across the window would make
/// them read as a filter over the content rather than as the window's chrome.
struct SettingsTabBar: View {
  @Binding var selection: SettingsTab

  var body: some View {
    HStack(spacing: SettingsChrome.tabSpacing) {
      ForEach(SettingsTab.allCases) { tab in
        Button {
          selection = tab
        } label: {
          VStack(spacing: 3) {
            Image(systemName: tab.symbol)
              .font(.system(size: 17, weight: .regular))
            Text(tab.title)
              .font(SettingsChrome.tabLabelFont)
          }
          .frame(width: SettingsChrome.tabSize.width, height: SettingsChrome.tabSize.height)
          .foregroundStyle(
            selection == tab ? Color.accentColor : SettingsChrome.secondaryText
          )
          .background(
            RoundedRectangle(cornerRadius: SettingsChrome.tabRadius)
              .fill(selection == tab ? SettingsChrome.selectedTabTint : .clear)
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(SettingsChrome.surface)
    .overlay(alignment: .bottom) {
      Rectangle().fill(SettingsChrome.border).frame(height: 1)
    }
  }
}

// MARK: - Page

/// One tab's content: a scrolling column of cards over the page background.
/// Scrolling lives inside the page so switching tabs never resizes the window.
struct SettingsPage<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: SettingsChrome.cardSpacing) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(SettingsChrome.pagePadding)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(SettingsChrome.background)
  }
}

// MARK: - Card

/// A rounded, bordered container holding one or more rows. Rows are separated
/// by `SettingsRowDivider`, placed explicitly by the caller — SwiftUI has no
/// public way to inject a separator between an opaque `ViewBuilder`'s children.
struct SettingsCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) {
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(SettingsChrome.surface)
    .clipShape(RoundedRectangle(cornerRadius: SettingsChrome.cardRadius))
    .overlay(
      RoundedRectangle(cornerRadius: SettingsChrome.cardRadius)
        .stroke(SettingsChrome.border, lineWidth: 1)
    )
  }
}

/// The hairline between two rows of a card.
struct SettingsRowDivider: View {
  var body: some View {
    Rectangle()
      .fill(SettingsChrome.border)
      .frame(height: 1)
      .padding(.leading, SettingsChrome.rowHorizontalPadding)
  }
}

/// One row whose control sits under the title rather than beside it, for a
/// control that wants the row's whole width — a slider next to its label would
/// be squeezed into whatever the label left over.
struct SettingsStackedRow<Content: View>: View {
  let title: String
  var caption: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(SettingsChrome.rowTitleFont)
          .foregroundStyle(SettingsChrome.primaryText)
        if let caption {
          Text(caption)
            .font(SettingsChrome.rowCaptionFont)
            .foregroundStyle(SettingsChrome.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      content
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
    .padding(.vertical, SettingsChrome.rowVerticalPadding)
  }
}

/// One row: a title, an optional caption under it, and a trailing control.
struct SettingsRow<Control: View>: View {
  let title: String
  var caption: String?
  @ViewBuilder var control: Control

  var body: some View {
    HStack(alignment: .center, spacing: SettingsChrome.rowControlSpacing) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(SettingsChrome.rowTitleFont)
          .foregroundStyle(SettingsChrome.primaryText)
        if let caption {
          Text(caption)
            .font(SettingsChrome.rowCaptionFont)
            .foregroundStyle(SettingsChrome.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      control
    }
    .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
    .padding(.vertical, SettingsChrome.rowVerticalPadding)
  }
}

// MARK: - Wording

// The state vocabulary, in one place because two tabs read from
// it: the ⌘ bindings on 一般 and the per-app rules on 個別.

func label(for action: KeyAction) -> String {
  switch action {
  case .eisuu: return "英数 (ABC)"
  case .kana: return "かな"
  case .none: return "何もしない"
  }
}

/// The same three actions, short enough to sit on a key cap.
func shortLabel(for action: KeyAction) -> String {
  switch action {
  case .eisuu: return "英数"
  case .kana: return "かな"
  case .none: return "—"
  }
}

func label(for action: AppRuleAction) -> String {
  switch action {
  case .noSwitch: return "切り替えない"
  case .eisuuOnActivate: return "前面で英数"
  case .kanaOnActivate: return "前面でかな"
  }
}
