// ActivationPolicy.swift
// Decides whether an app coming to the front should have its default input
// source applied (F-17).

import Foundation

/// Applies a per-app default at most once per activation.
///
/// Without the "once" rule, every input-source notification would look like a
/// chance to re-apply, and a user who taps ⌘ to override the default would be
/// pushed straight back. The rule is that an override holds until
/// the app is brought forward again, so the trigger is the activation event and
/// not the input-source state.
public struct ActivationPolicy: Sendable {
  private var appliedFor: String?

  public init() {}

  /// Called when `bundleID` becomes frontmost. Returns the input source to
  /// force, or nil when there is nothing to do.
  public mutating func inputSourceOnActivation(
    of bundleID: String?,
    settings: Settings
  ) -> InputSourceKind? {
    defer { appliedFor = bundleID }
    guard bundleID != appliedFor else { return nil }
    return settings.rule(forBundleID: bundleID)?.action.activationInputSource
  }

  /// Forgets the last activation, so the next one applies again. Used when the
  /// rules change under the frontmost app.
  public mutating func reset() {
    appliedFor = nil
  }
}
