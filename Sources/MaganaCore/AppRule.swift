// AppRule.swift
// One row of the per-app table: an app, and what should happen while it is
// frontmost.

/// What an app in the per-app table does.
///
/// `noSwitch` is F-8 (leave ⌘ alone so the app receives it), the other two are
/// F-17 (force an input source the moment the app comes forward). They share
/// one table because they are both "this app, this behaviour".
public enum AppRuleAction: String, Codable, Sendable, CaseIterable {
  case noSwitch = "no_switch"
  case eisuuOnActivate = "eisuu_on_activate"
  case kanaOnActivate = "kana_on_activate"

  /// The input source to force when this app becomes frontmost, if any.
  public var activationInputSource: InputSourceKind? {
    switch self {
    case .noSwitch: return nil
    case .eisuuOnActivate: return .eisuu
    case .kanaOnActivate: return .kana
    }
  }
}

public struct AppRule: Codable, Sendable, Equatable, Identifiable {
  /// Matching is by bundle identifier, so a rule survives the app moving on
  /// disk and an app that is uninstalled keeps its row.
  public let bundleID: String
  public var displayName: String
  public var action: AppRuleAction

  public var id: String { bundleID }

  public init(bundleID: String, displayName: String, action: AppRuleAction) {
    self.bundleID = bundleID
    self.displayName = displayName
    self.action = action
  }

  private enum CodingKeys: String, CodingKey {
    case bundleID = "bundle_id"
    case displayName = "display_name"
    case action
  }
}
