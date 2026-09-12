// SemanticVersion.swift
// The version of a build, as a value that can be compared.

/// A `major.minor.patch` version.
///
/// Parsing is strict on purpose: the only two shapes it accepts are the one in
/// `CFBundleShortVersionString` (`1.2.3`) and the one GitHub puts on a tag
/// (`v1.2.3`). Anything else means the release was tagged in a way this app
/// cannot reason about, and guessing a version is worse than refusing to
/// update (F-14).
public struct SemanticVersion: Comparable, CustomStringConvertible, Sendable {
  public let major: Int
  public let minor: Int
  public let patch: Int

  public init(major: Int, minor: Int, patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  public init?(_ string: String) {
    let raw = string.hasPrefix("v") ? String(string.dropFirst()) : string
    let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    // Int("+1") and Int(" 1") both parse, so the digits are checked directly
    // rather than left to Int's tolerance.
    let isDigits = { (part: Substring) in
      !part.isEmpty && part.allSatisfy { $0.isASCII && $0.isNumber }
    }
    guard parts.allSatisfy(isDigits),
      let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2])
    else { return nil }
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  public var description: String { "\(major).\(minor).\(patch)" }

  public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
    (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
  }
}
