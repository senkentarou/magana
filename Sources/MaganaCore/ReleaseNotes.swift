// ReleaseNotes.swift
// Splits a GitHub release body into the blocks the update window draws.
//
// Hand-rolled rather than a CommonMark dependency: release notes only reach
// for headings, lists, blockquotes, fenced code, tables and horizontal rules,
// and the whole updater is smaller than a Markdown implementation would be.
// Inline syntax — bold, links, code spans — is left
// to `AttributedString(markdown:)` at the draw site; this file only decides
// where one block ends and the next begins.

import Foundation

/// The marker a list item was written with.
public enum ReleaseNoteListMarker: Equatable, Sendable {
  case bullet
  case ordered(Int)
}

/// One column's alignment, read from the delimiter row (`:---` leading,
/// `:---:` centre, `---:` trailing, plain `---` leading).
public enum ReleaseNoteTableAlignment: Equatable, Sendable {
  case leading
  case center
  case trailing
}

/// A parsed table: header cells, one alignment per column, and body rows, each
/// padded or cut to the header's column count so a row can be drawn without
/// checking its length again.
public struct ReleaseNoteTable: Equatable, Sendable {
  public let header: [String]
  public let alignments: [ReleaseNoteTableAlignment]
  public let rows: [[String]]

  public init(
    header: [String], alignments: [ReleaseNoteTableAlignment], rows: [[String]]
  ) {
    self.header = header
    self.alignments = alignments
    self.rows = rows
  }
}

/// One block of a release note. Every `String` still carries its inline
/// markup, because the caller is the one that renders it.
public enum ReleaseNoteBlock: Equatable, Sendable {
  case heading(level: Int, text: String)
  case listItem(indent: Int, marker: ReleaseNoteListMarker, text: String)
  case paragraph(String)
  case quote([String])
  case table(ReleaseNoteTable)
  case code(String)
  case rule
  case blank
}

public enum ReleaseNotes {

  /// Reads a release body into blocks, one line at a time.
  ///
  /// Wrapped lines are kept as separate paragraphs rather than joined: the
  /// notes are Japanese, and joining two lines with a space would put one
  /// between characters that belong next to each other.
  public static func parse(_ notes: String) -> [ReleaseNoteBlock] {
    let lines = notes.components(separatedBy: "\n")
    var blocks: [ReleaseNoteBlock] = []
    var index = 0

    while index < lines.count {
      let rawLine = lines[index]
      let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

      if trimmed.isEmpty {
        blocks.append(.blank)
        index += 1
        continue
      }

      if let fence = fenceMarker(trimmed) {
        index += 1
        var codeLines: [String] = []
        while index < lines.count {
          if lines[index].trimmingCharacters(in: .whitespaces) == fence {
            index += 1
            break
          }
          codeLines.append(lines[index])
          index += 1
        }
        blocks.append(.code(codeLines.joined(separator: "\n")))
        continue
      }

      // Before the horizontal rule below, so a delimiter row such as
      // `|---|---|` is read as part of the table and not as a rule.
      if trimmed.contains("|"), index + 1 < lines.count,
        let alignments = tableDelimiterAlignments(lines[index + 1])
      {
        let header = splitTableRow(trimmed)
        let columnCount = header.count
        index += 2  // the header and its delimiter
        var rows: [[String]] = []
        while index < lines.count {
          let bodyLine = lines[index].trimmingCharacters(in: .whitespaces)
          guard bodyLine.contains("|") else { break }
          rows.append(fit(splitTableRow(bodyLine), to: columnCount, with: ""))
          index += 1
        }
        blocks.append(
          .table(
            ReleaseNoteTable(
              header: header,
              alignments: fit(alignments, to: columnCount, with: .leading),
              rows: rows)))
        continue
      }

      if isHorizontalRule(trimmed) {
        blocks.append(.rule)
        index += 1
        continue
      }

      if trimmed.hasPrefix(">") {
        var quoteLines: [String] = []
        while index < lines.count {
          let line = lines[index].trimmingCharacters(in: .whitespaces)
          guard line.hasPrefix(">") else { break }
          var remainder = line.dropFirst()
          if remainder.hasPrefix(" ") {
            remainder.removeFirst()
          }
          quoteLines.append(String(remainder))
          index += 1
        }
        blocks.append(.quote(quoteLines))
        continue
      }

      if trimmed.hasPrefix("#") {
        let hashes = trimmed.prefix(while: { $0 == "#" })
        let rest = trimmed.dropFirst(hashes.count)
        if (1...6).contains(hashes.count), rest.hasPrefix(" ") {
          blocks.append(
            .heading(level: hashes.count, text: String(rest.drop(while: { $0 == " " }))))
          index += 1
          continue
        }
        // Falls through to a paragraph: no space after the hashes (`#tag`) or
        // more than six of them, neither of which is a heading.
      }

      let indent = min(rawLine.prefix(while: { $0 == " " }).count / 2, 3)

      if let text = bulletText(trimmed) {
        blocks.append(.listItem(indent: indent, marker: .bullet, text: text))
        index += 1
        continue
      }

      if let (number, text) = orderedListItem(trimmed) {
        blocks.append(.listItem(indent: indent, marker: .ordered(number), text: text))
        index += 1
        continue
      }

      blocks.append(.paragraph(trimmed))
      index += 1
    }

    return blocks
  }

  // MARK: - Line classifiers

  /// The fence a line opens a code block with (```` ``` ```` or `~~~`),
  /// ignoring the language written after it.
  private static func fenceMarker(_ line: String) -> String? {
    if line.hasPrefix("```") {
      return String(line.prefix(while: { $0 == "`" }))
    }
    if line.hasPrefix("~~~") {
      return String(line.prefix(while: { $0 == "~" }))
    }
    return nil
  }

  /// Three or more of `-`, `*` or `_`, and nothing else.
  private static func isHorizontalRule(_ line: String) -> Bool {
    guard line.count >= 3, let first = line.first, "-*_".contains(first) else { return false }
    return line.allSatisfy { $0 == first }
  }

  private static func bulletText(_ line: String) -> String? {
    for marker in ["- ", "* ", "+ ", "• "] where line.hasPrefix(marker) {
      return String(line.dropFirst(marker.count))
    }
    return nil
  }

  private static func orderedListItem(_ line: String) -> (Int, String)? {
    guard let match = line.range(of: "^\\d+\\.\\s", options: .regularExpression) else {
      return nil
    }
    let digits = line[line.startIndex..<match.upperBound].prefix(while: { $0.isNumber })
    return (Int(digits) ?? 0, String(line[match.upperBound...]))
  }

  // MARK: - Tables

  /// Splits a row on `|`, dropping the empty cell the outer pipes of
  /// `| a | b |` produce and trimming what is left.
  private static func splitTableRow(_ line: String) -> [String] {
    var cells = line.components(separatedBy: "|")
    if let first = cells.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
      cells.removeFirst()
    }
    if let last = cells.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
      cells.removeLast()
    }
    return cells.map { $0.trimmingCharacters(in: .whitespaces) }
  }

  /// The per-column alignments if `line` is a delimiter row, `nil` otherwise.
  ///
  /// The `|` is required so a plain `---` is not read as a one-column
  /// delimiter, which would swallow the horizontal rule under any line that
  /// happens to contain a pipe and leave an empty table behind.
  private static func tableDelimiterAlignments(_ line: String) -> [ReleaseNoteTableAlignment]? {
    guard line.contains("|") else { return nil }
    let cells = splitTableRow(line)
    guard !cells.isEmpty else { return nil }
    var alignments: [ReleaseNoteTableAlignment] = []
    for cell in cells {
      guard cell.range(of: "^:?-{1,}:?$", options: .regularExpression) != nil else { return nil }
      switch (cell.hasPrefix(":"), cell.hasSuffix(":")) {
      case (true, true): alignments.append(.center)
      case (false, true): alignments.append(.trailing)
      default: alignments.append(.leading)  // `:---` and a plain `---`
      }
    }
    return alignments
  }

  private static func fit<T>(_ array: [T], to count: Int, with value: T) -> [T] {
    array.count < count
      ? array + Array(repeating: value, count: count - array.count)
      : Array(array.prefix(count))
  }
}
