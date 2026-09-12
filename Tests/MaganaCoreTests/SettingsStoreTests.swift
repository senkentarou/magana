// SettingsStoreTests.swift
// Verifies that settings survive a restart and that a damaged blob does not
// take the app down with it (F-7).

import Foundation
import Testing

@testable import MaganaCore

@Suite("Settings persistence")
struct SettingsStoreTests {

  /// Each test gets its own defaults domain so the suite never reads or writes
  /// the real user's preferences.
  private func withSuite(_ body: (UserDefaults) throws -> Void) rethrows {
    let name = "com.senkentarou.magana.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { UserDefaults.standard.removePersistentDomain(forName: name) }
    try body(defaults)
  }

  @Test("An empty store returns the defaults")
  func emptyStore() {
    withSuite { defaults in
      #expect(SettingsStore(defaults: defaults).load() == .default)
    }
  }

  @Test("Every field survives a round trip (F-7)")
  func roundTrip() {
    withSuite { defaults in
      var settings = Settings.default
      settings.leftAction = .kana
      settings.rightAction = .none
      settings.aloneTimeoutMilliseconds = 450
      settings.disableOnJIS = false
      settings.launchAtLogin = false
      settings.autoCheckUpdates = false
      settings.paused = true
      settings.appRules = [
        AppRule(
          bundleID: "com.parallels.desktop.console", displayName: "Parallels Desktop",
          action: .noSwitch),
        AppRule(bundleID: "com.apple.Terminal", displayName: "Terminal", action: .eisuuOnActivate),
      ]

      SettingsStore(defaults: defaults).save(settings)
      #expect(SettingsStore(defaults: defaults).load() == settings)
    }
  }

  @Test("A blob that cannot be decoded falls back to the defaults")
  func corruptBlob() {
    withSuite { defaults in
      defaults.set(Data("not json".utf8), forKey: SettingsStore.defaultsKey)
      #expect(SettingsStore(defaults: defaults).load() == .default)
    }
  }

  @Test("A blob written by an older build keeps the fields it does have")
  func partialBlob() {
    withSuite { defaults in
      // show_hud is a field this build no longer has; a blob written before it
      // was dropped must still load, and the fields around it must survive.
      let json = #"{"left_action":"kana","alone_timeout_ms":300,"show_hud":true}"#
      defaults.set(Data(json.utf8), forKey: SettingsStore.defaultsKey)

      let loaded = SettingsStore(defaults: defaults).load()
      #expect(loaded.leftAction == .kana)
      #expect(loaded.aloneTimeoutMilliseconds == 300)
      #expect(loaded.rightAction == Settings.default.rightAction)
      #expect(loaded.disableOnJIS == Settings.default.disableOnJIS)
      #expect(loaded.launchAtLogin == Settings.default.launchAtLogin)
      // Written before F-14 existed: the update check has to start on, not on
      // Bool's false.
      #expect(loaded.autoCheckUpdates)
    }
  }

  @Test("A rule naming an unknown action is dropped, not the whole blob")
  func unknownRuleAction() {
    withSuite { defaults in
      // What a downgrade looks like: a newer build wrote a rule whose action
      // this build has never heard of. Decoding [AppRule] as a whole would
      // throw, load() would swallow it, and the ⌘ bindings would silently go
      // back to the defaults along with the rule.
      let json = """
        {"left_action":"kana","app_rules":[
          {"bundle_id":"com.apple.Terminal","display_name":"Terminal","action":"eisuu_on_activate"},
          {"bundle_id":"com.example.new","display_name":"New","action":"something_this_build_lacks"}
        ]}
        """
      defaults.set(Data(json.utf8), forKey: SettingsStore.defaultsKey)

      let loaded = SettingsStore(defaults: defaults).load()
      #expect(loaded.leftAction == .kana)
      #expect(loaded.appRules.count == 1)
      #expect(loaded.appRules.first?.bundleID == "com.apple.Terminal")
    }
  }

  @Test("A timeout from outside the allowed range is clamped on load")
  func timeoutOutOfRange() {
    withSuite { defaults in
      // A negative timeout makes `event.timestamp - downAt < timeout` false for
      // every tap, so nothing ever switches — and the settings window would
      // still show 200ms, because it clamps what it displays.
      defaults.set(Data(#"{"alone_timeout_ms":-1}"#.utf8), forKey: SettingsStore.defaultsKey)
      #expect(
        SettingsStore(defaults: defaults).load().aloneTimeoutMilliseconds
          == Settings.aloneTimeoutRange.lowerBound)

      defaults.set(Data(#"{"alone_timeout_ms":99999}"#.utf8), forKey: SettingsStore.defaultsKey)
      #expect(
        SettingsStore(defaults: defaults).load().aloneTimeoutMilliseconds
          == Settings.aloneTimeoutRange.upperBound)
    }
  }

  @Test("Launching at login is on until the user says otherwise (F-10)")
  func launchAtLoginDefaultsOn() {
    #expect(Settings.default.launchAtLogin)
  }

  @Test("A first launch is told apart from a launch with settings saved")
  func firstLaunchIsDistinguishable() {
    withSuite { defaults in
      let store = SettingsStore(defaults: defaults)
      #expect(!store.hasStoredSettings)
      store.save(.default)
      #expect(store.hasStoredSettings)
    }
  }

  @Test("A rule is found by bundle identifier")
  func ruleLookup() {
    var settings = Settings.default
    settings.appRules = [
      AppRule(bundleID: "com.tinyspeck.slackmacgap", displayName: "Slack", action: .kanaOnActivate)
    ]
    #expect(settings.rule(forBundleID: "com.tinyspeck.slackmacgap")?.action == .kanaOnActivate)
    #expect(settings.rule(forBundleID: "com.apple.Safari") == nil)
    #expect(settings.rule(forBundleID: nil) == nil)
  }
}
