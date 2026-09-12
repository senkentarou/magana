// Settings.swift
// Everything the user can change, as one Codable value.

import Foundation

/// The persisted settings.
///
/// One value rather than a key per setting: it is a handful of fields that are
/// always read together, and a single blob cannot drift into a half-migrated
/// state where the left ⌘ has been saved by a new build and the right ⌘ has
/// not.
public struct Settings: Codable, Sendable, Equatable {
  public var leftAction: KeyAction
  public var rightAction: KeyAction
  public var aloneTimeoutMilliseconds: Int
  public var disableOnJIS: Bool
  public var launchAtLogin: Bool
  public var autoCheckUpdates: Bool
  public var paused: Bool
  public var appRules: [AppRule]

  /// The default the established remappers use for a tap, so the key feels
  /// the same as whatever the user is switching away from.
  public static let defaultAloneTimeoutMilliseconds = 1000
  /// The range the settings window allows. Below ~200ms a deliberate tap is
  /// missed; above ~2000ms an ordinary ⌘-hold starts firing.
  public static let aloneTimeoutRange = 200...2000

  /// `launchAtLogin` starts on: a menu bar app that is not running does
  /// nothing at all, so "install it and you are done" needs the
  /// default on this side.

  public static let `default` = Settings(
    leftAction: .eisuu,
    rightAction: .kana,
    aloneTimeoutMilliseconds: defaultAloneTimeoutMilliseconds,
    disableOnJIS: true,
    launchAtLogin: true,
    autoCheckUpdates: true,
    paused: false,
    appRules: []
  )

  public init(
    leftAction: KeyAction,
    rightAction: KeyAction,
    aloneTimeoutMilliseconds: Int,
    disableOnJIS: Bool,
    launchAtLogin: Bool,
    autoCheckUpdates: Bool,
    paused: Bool,
    appRules: [AppRule]
  ) {
    self.leftAction = leftAction
    self.rightAction = rightAction
    self.aloneTimeoutMilliseconds = aloneTimeoutMilliseconds
    self.disableOnJIS = disableOnJIS
    self.launchAtLogin = launchAtLogin
    self.autoCheckUpdates = autoCheckUpdates
    self.paused = paused
    self.appRules = appRules
  }

  /// Decoding tolerates a missing field so that a settings blob written by an
  /// older build keeps its other values instead of resetting wholesale.
  ///
  /// `decodeIfPresent` only covers a key that is absent. A key that is present
  /// and undecodable — a rule naming an action a newer build introduced — still
  /// throws, and `SettingsStore.load` turns any throw into the defaults, so one
  /// unreadable row would silently reset the ⌘ bindings too. `appRules` is
  /// therefore decoded row by row and the unreadable rows are dropped.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let fallback = Settings.default
    leftAction = try c.decodeIfPresent(KeyAction.self, forKey: .leftAction) ?? fallback.leftAction
    rightAction =
      try c.decodeIfPresent(KeyAction.self, forKey: .rightAction) ?? fallback.rightAction
    // Clamped here rather than at every reader. The settings window used to be
    // the only thing holding the range, so a blob carrying a number from
    // outside it showed 200 in the slider while `AloneDetector` ran on the raw
    // value — and a negative one makes every tap read as a hold, which is the
    // shape of the bug in 7771027.
    aloneTimeoutMilliseconds = Settings.clampAloneTimeout(
      try c.decodeIfPresent(Int.self, forKey: .aloneTimeoutMilliseconds)
        ?? fallback.aloneTimeoutMilliseconds)
    disableOnJIS = try c.decodeIfPresent(Bool.self, forKey: .disableOnJIS) ?? fallback.disableOnJIS
    launchAtLogin =
      try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
    autoCheckUpdates =
      try c.decodeIfPresent(Bool.self, forKey: .autoCheckUpdates) ?? fallback.autoCheckUpdates
    paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? fallback.paused
    appRules =
      (try c.decodeIfPresent([LenientlyDecoded<AppRule>].self, forKey: .appRules))?
      .compactMap(\.value) ?? fallback.appRules
  }

  /// Keeps the timeout inside `aloneTimeoutRange`.
  public static func clampAloneTimeout(_ milliseconds: Int) -> Int {
    min(max(milliseconds, aloneTimeoutRange.lowerBound), aloneTimeoutRange.upperBound)
  }

  public func rule(forBundleID bundleID: String?) -> AppRule? {
    guard let bundleID else { return nil }
    return appRules.first { $0.bundleID == bundleID }
  }

  private enum CodingKeys: String, CodingKey {
    case leftAction = "left_action"
    case rightAction = "right_action"
    case aloneTimeoutMilliseconds = "alone_timeout_ms"
    case disableOnJIS = "disable_on_jis"
    case launchAtLogin = "launch_at_login"
    case autoCheckUpdates = "auto_check_updates"
    case paused
    case appRules = "app_rules"
  }
}

/// One element of an array, decoded so that a bad element is `nil` rather than
/// an error that takes the whole array — and, through `SettingsStore.load`,
/// every unrelated setting — with it.
private struct LenientlyDecoded<Value: Decodable>: Decodable {
  let value: Value?

  init(from decoder: any Decoder) throws {
    value = try? Value(from: decoder)
  }
}
