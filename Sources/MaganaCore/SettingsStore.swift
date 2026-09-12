// SettingsStore.swift
// Reads and writes the settings blob. UserDefaults is injected so tests run
// against a throwaway suite instead of the real user's preferences.

import Foundation

public final class SettingsStore {
  /// One key holds the whole Codable value, which also makes the
  /// stored state readable with `defaults read com.senkentarou.magana settings`.
  public static let defaultsKey = "settings"

  private let defaults: UserDefaults
  private let lock = NSLock()

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  /// Whether this Mac has ever saved settings. Distinguishes a first launch
  /// from a launch where the user has turned something off, which is what
  /// `launchAtLogin` needs to know before it registers a login item.
  public var hasStoredSettings: Bool {
    lock.lock()
    defer { lock.unlock() }
    return defaults.data(forKey: Self.defaultsKey) != nil
  }

  /// Returns the stored settings, or the defaults if nothing is stored or the
  /// stored blob cannot be decoded. A corrupt blob is left in place rather than
  /// erased; the next `save` overwrites it.
  public func load() -> Settings {
    lock.lock()
    defer { lock.unlock() }
    guard
      let data = defaults.data(forKey: Self.defaultsKey),
      let decoded = try? JSONDecoder().decode(Settings.self, from: data)
    else { return .default }
    return decoded
  }

  public func save(_ settings: Settings) {
    lock.lock()
    defer { lock.unlock() }
    guard let data = try? JSONEncoder().encode(settings) else { return }
    defaults.set(data, forKey: Self.defaultsKey)
  }
}
