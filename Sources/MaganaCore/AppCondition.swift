// AppCondition.swift
// What the app's state adds up to: one status for the menu's first line, and
// the warnings that go above the actions.

import Foundation

/// What the menu's first line says. These four are the whole state vocabulary
/// the UI is allowed to use.
public enum AppStatus: Sendable, Equatable {
  case active
  case paused
  case noPermission
  case disabledByJISKeyboard
}

/// A reason the menu shows a line above the actions. The wording lives in the
/// view; the decision to show it lives here.
public enum AppWarning: Sendable, Equatable, CaseIterable {
  case permissionMissing
  case noJapaneseInputSource
  case jisKeyboardConnected
}

/// The facts the status and the warnings are derived from.
///
/// Derived state, not an OS call in sight — and yet it lived in `AppController`
/// where no test could reach it. That is the same place the menu bar badge sat
/// while it spent four commits pointing at the wrong ⌘ (f79871f, ff43ac6,
/// 39226ed): a wrong answer here is invisible to `make check` and to review,
/// and only shows up on the machine.
public struct AppCondition: Sendable, Equatable {
  public var isTrusted: Bool
  public var paused: Bool
  public var disableOnJIS: Bool
  public var hasJISKeyboard: Bool
  public var hasJapaneseSource: Bool

  public init(
    isTrusted: Bool,
    paused: Bool,
    disableOnJIS: Bool,
    hasJISKeyboard: Bool,
    hasJapaneseSource: Bool
  ) {
    self.isTrusted = isTrusted
    self.paused = paused
    self.disableOnJIS = disableOnJIS
    self.hasJISKeyboard = hasJISKeyboard
    self.hasJapaneseSource = hasJapaneseSource
  }

  /// The one state word for the menu.
  ///
  /// The order is the priority: no permission outranks everything because
  /// nothing else can be true without it, and a pause the user asked for
  /// outranks the JIS stand-down because it is the one they will look for.
  public var status: AppStatus {
    if !isTrusted { return .noPermission }
    if paused { return .paused }
    if disableOnJIS && hasJISKeyboard { return .disabledByJISKeyboard }
    return .active
  }

  /// Whether a ⌘ tap is allowed to post anything at all.
  public var canSwitch: Bool { status == .active }

  /// Every warning that applies, in the order the menu shows them.
  ///
  /// Not exclusive with each other or with `status`: the permission can be
  /// missing while there is also no Japanese input source, and the user needs
  /// to be told both.
  public var warnings: [AppWarning] {
    var warnings: [AppWarning] = []
    if !isTrusted { warnings.append(.permissionMissing) }
    if !hasJapaneseSource { warnings.append(.noJapaneseInputSource) }
    if disableOnJIS && hasJISKeyboard { warnings.append(.jisKeyboardConnected) }
    return warnings
  }
}
