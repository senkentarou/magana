// UpdateView.swift
// The update window. Same skeleton as the
// sister app's: a heading that names the app in every state, then one body
// that fills the rest.

import AppKit
import MaganaCore
import SwiftUI

struct UpdateView: View {
  @ObservedObject var updater: UpdateController
  @Environment(\.dismiss) private var dismiss

  /// Sized for the state with the most in it — a release with its notes.
  /// Everything else centres itself in the same frame, so the window does not
  /// jump as the update moves from one state to the next.
  private static let size = CGSize(width: 460, height: 520)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .onAppear {
      // Opened with nothing behind it — a window restored at launch, say.
      // Checking now is the honest answer; "最新です" would be a claim about a
      // comparison nobody has made.
      if case .idle = updater.phase { updater.check(userInitiated: true) }
    }
  }

  // MARK: - Header

  /// The app's icon, its name and one line of state. In every state, so the
  /// window is never an anonymous box of text.
  private var header: some View {
    HStack(spacing: 14) {
      if let icon = NSApp.applicationIconImage {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 52, height: 52)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text("Magana")
          .font(.title2.weight(.semibold))
        Text(headline)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 18)
  }

  private var headline: String {
    switch updater.phase {
    case .idle, .checking: "アップデートを確認しています…"
    case .upToDate: "お使いのバージョンは最新です"
    case .available: "新しいバージョンがあります"
    case .downloading: "ダウンロードしています…"
    case .verifying: "ダウンロードしたものを確認しています…"
    case .installing: "入れ替えています…"
    case .failed: "エラーが発生しました"
    }
  }

  // MARK: - Body

  @ViewBuilder
  private var content: some View {
    switch updater.phase {
    case .idle, .checking:
      waiting(caption: nil, closable: true)
    case .upToDate:
      upToDate
    case .available(let release):
      available(release)
    case .downloading(let fraction):
      downloading(fraction)
    case .verifying:
      waiting(caption: nil, closable: false)
    case .installing:
      waiting(caption: "まもなく Magana が再起動します", closable: false)
    case .failed(let message, let canCheckAgain):
      failed(message, canCheckAgain: canCheckAgain)
    }
  }

  /// A new release: which version replaces which, the notes, and the two
  /// buttons that decide it.
  private func available(_ release: ReleaseInfo) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 8) {
        Text(UpdateController.currentVersion.description)
          .foregroundStyle(.secondary)
        Image(systemName: "arrow.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(release.version.description)
          .fontWeight(.semibold)
        Text(subtitle(for: release))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .font(.callout)

      HStack {
        Text("リリースノート")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Button("GitHub で見る") { updater.openReleasePage() }
          .buttonStyle(.link)
          .font(.caption)
      }

      notes(for: release)

      HStack(spacing: 10) {
        Spacer()
        Button("あとで") { dismiss() }
        Button("更新して再起動") { updater.installAvailable() }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(24)
  }

  private var upToDate: some View {
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44))
        .foregroundStyle(.green)
      Text("バージョン \(AppVersion.short) をお使いです")
        .font(.callout)
        .foregroundStyle(.secondary)
      Spacer()
      HStack {
        // Only once a check has seen a release: without one there is no page
        // to open but the repository's, which is not what the link says.
        if updater.latest != nil {
          Button("GitHub で見る") { updater.openReleasePage() }
            .buttonStyle(.link)
            .font(.caption)
        }
        Spacer()
        Button("閉じる") { dismiss() }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(24)
  }

  private func downloading(_ fraction: Double) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Spacer()
      ProgressView(value: fraction)
      Text("\(Int(fraction * 100))% 完了")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding(24)
  }

  /// The states with nothing to decide: checking, verifying, installing.
  /// `closable` is what tells them apart — an install underway is not a thing
  /// to walk away from.
  private func waiting(caption: String?, closable: Bool) -> some View {
    VStack(spacing: 16) {
      Spacer()
      ProgressView()
        .scaleEffect(1.4)
      if let caption {
        Text(caption)
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      Spacer()
      if closable {
        HStack {
          Spacer()
          Button("閉じる") { dismiss() }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(24)
  }

  /// A failure, with the one action that answers it: check again when the
  /// check is what failed, the release page when the download or the swap did.
  private func failed(_ message: String, canCheckAgain: Bool) -> some View {
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 40))
        .foregroundStyle(.orange)
      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      Spacer()
      HStack {
        Spacer()
        Button("閉じる") { dismiss() }
        if canCheckAgain {
          Button("もう一度確認") { updater.check(userInitiated: true) }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        } else {
          Button("リリースページを開く") { updater.openReleasePage() }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
      }
    }
    .padding(24)
  }

  // MARK: - Release notes

  private func notes(for release: ReleaseInfo) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 6) {
        // A block is not `Identifiable`, and the blocks of one release never
        // reorder, so the position in the list is a stable identity here.
        ForEach(Array(blocks(of: release).enumerated()), id: \.offset) { _, block in
          view(for: block)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
      .padding(12)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .textBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
  }

  private func blocks(of release: ReleaseInfo) -> [ReleaseNoteBlock] {
    let text = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return [.paragraph("（リリースノートはありません）")] }
    return ReleaseNotes.parse(text)
  }

  @ViewBuilder
  private func view(for block: ReleaseNoteBlock) -> some View {
    switch block {
    case .heading(_, let text):
      Text(inline(text))
        .font(.callout.weight(.bold))
        .padding(.top, 6)
    case .listItem(let indent, let marker, let text):
      listItem(indent: indent, marker: marker, text: text)
    case .paragraph(let text):
      Text(inline(text))
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    case .quote(let lines):
      quote(lines)
    case .table(let table):
      grid(for: table)
    case .code(let raw):
      code(raw)
    case .rule:
      Divider().padding(.vertical, 4)
    case .blank:
      Color.clear.frame(height: 2)
    }
  }

  private func listItem(
    indent: Int, marker: ReleaseNoteListMarker, text: String
  ) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label(for: marker))
        .foregroundStyle(.secondary)
      Text(inline(text))
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.leading, CGFloat(indent) * 16)
  }

  /// A rule down the left, stretched to the quote's height by the stack, and
  /// the lines dimmed so the quote reads as somebody else's words.
  private func quote(_ lines: [String]) -> some View {
    HStack(alignment: .top, spacing: 8) {
      RoundedRectangle(cornerRadius: 1.5)
        .fill(Color(nsColor: .separatorColor))
        .frame(width: 3)
      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
          Text(inline(line))
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 4)
  }

  /// A `Grid` rather than stacked rows: the columns have to line up across
  /// rows, which is the one thing a `VStack` of `HStack`s cannot do. The
  /// alignment is applied to the header cell, which sets it for the column.
  private func grid(for table: ReleaseNoteTable) -> some View {
    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
      GridRow {
        ForEach(Array(table.header.enumerated()), id: \.offset) { column, cell in
          Text(inline(cell))
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .gridColumnAlignment(alignment(of: table.alignments[column]))
        }
      }
      GridRow {
        // Unsized across, so the full-width rule does not decide how wide a
        // column is.
        Divider()
          .gridCellColumns(table.header.count)
          .gridCellUnsizedAxes(.horizontal)
      }
      ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
        GridRow {
          ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
            Text(inline(cell))
              .font(.callout)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  private func code(_ raw: String) -> some View {
    Text(raw)
      .font(.system(.caption, design: .monospaced))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(8)
      .background(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private func label(for marker: ReleaseNoteListMarker) -> String {
    switch marker {
    case .bullet: "•"
    case .ordered(let number): "\(number)."
    }
  }

  private func alignment(of column: ReleaseNoteTableAlignment) -> HorizontalAlignment {
    switch column {
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    }
  }

  /// What is left inside one block — bold, links, code spans. Whitespace is
  /// preserved so the line breaks the author wrote survive; the blocks around
  /// it were resolved by `ReleaseNotes.parse`.
  private func inline(_ text: String) -> AttributedString {
    (try? AttributedString(
      markdown: text,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(text)
  }

  private func subtitle(for release: ReleaseInfo) -> String {
    var parts: [String] = []
    if let published = release.publishedAt {
      parts.append(published.formatted(date: .numeric, time: .omitted) + " 公開")
    }
    if release.assetSize > 0 {
      parts.append(release.assetSize.formatted(.byteCount(style: .file)))
    }
    return parts.joined(separator: " · ")
  }
}
