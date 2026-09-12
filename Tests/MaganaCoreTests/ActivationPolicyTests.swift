// ActivationPolicyTests.swift
// Verifies that a per-app default is applied on activation and not re-applied
// after the user overrides it (F-17).

import Testing

@testable import MaganaCore

private let terminal = "com.apple.Terminal"
private let slack = "com.tinyspeck.slackmacgap"
private let safari = "com.apple.Safari"

private let settings: Settings = {
  var s = Settings.default
  s.appRules = [
    AppRule(bundleID: terminal, displayName: "Terminal", action: .eisuuOnActivate),
    AppRule(bundleID: slack, displayName: "Slack", action: .kanaOnActivate),
    AppRule(bundleID: "com.parallels.desktop.console", displayName: "Parallels", action: .noSwitch),
  ]
  return s
}()

@Suite("Per-app default input source")
struct ActivationPolicyTests {

  @Test("Bringing a configured app forward applies its default")
  func appliesOnActivation() {
    var policy = ActivationPolicy()
    #expect(policy.inputSourceOnActivation(of: terminal, settings: settings) == .eisuu)
    #expect(policy.inputSourceOnActivation(of: slack, settings: settings) == .kana)
  }

  @Test("An app with no rule changes nothing")
  func unconfiguredApp() {
    var policy = ActivationPolicy()
    #expect(policy.inputSourceOnActivation(of: safari, settings: settings) == nil)
  }

  @Test("切り替えない has no activation default (F-8 is not F-17)")
  func noSwitchRule() {
    var policy = ActivationPolicy()
    #expect(
      policy.inputSourceOnActivation(of: "com.parallels.desktop.console", settings: settings) == nil
    )
  }

  @Test("A repeated activation notification does not re-apply over an override")
  func appliesOncePerActivation() {
    var policy = ActivationPolicy()
    #expect(policy.inputSourceOnActivation(of: terminal, settings: settings) == .eisuu)
    #expect(policy.inputSourceOnActivation(of: terminal, settings: settings) == nil)
  }

  @Test("Leaving and coming back applies the default again")
  func reappliesAfterLeaving() {
    var policy = ActivationPolicy()
    #expect(policy.inputSourceOnActivation(of: terminal, settings: settings) == .eisuu)
    #expect(policy.inputSourceOnActivation(of: safari, settings: settings) == nil)
    #expect(policy.inputSourceOnActivation(of: terminal, settings: settings) == .eisuu)
  }

  @Test("reset() makes the next activation apply again")
  func resetForcesReapply() {
    var policy = ActivationPolicy()
    _ = policy.inputSourceOnActivation(of: terminal, settings: settings)
    policy.reset()
    #expect(policy.inputSourceOnActivation(of: terminal, settings: settings) == .eisuu)
  }
}
