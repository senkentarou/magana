// InputSourceService.swift
// Reads which input source is current, and whether かな has anywhere to go.

import AppKit
import Carbon.HIToolbox
import MaganaCore

/// Watches the selected keyboard input source.
///
/// Read-only on purpose: the app changes the input source by posting keys
/// (`Switcher`), never by calling `TISSelectInputSource`. What this service is
/// for is F-6 — the menu bar letter has to follow a switch made by any means,
/// including ⌃Space or the input menu — and the idempotence check that keeps
/// F-1 / F-2 from posting a key that would change nothing.
@MainActor
final class InputSourceService {
  private(set) var current: InputSourceKind = .eisuu
  /// False when no Japanese IME is enabled, which is the one case where the
  /// かな side has nowhere to go.
  private(set) var hasJapaneseSource = true

  var onChange: (() -> Void)?

  /// Held, not read: releasing the token `addObserver(forName:)` returns ends
  /// the subscription, and this one lasts as long as the app.
  private var observers: [any NSObjectProtocol] = []

  func start() {
    refresh()
    observe(kTISNotifySelectedKeyboardInputSourceChanged)
    observe(kTISNotifyEnabledKeyboardInputSourcesChanged)
  }

  func refresh() {
    let previousKind = current
    let previousHasJapanese = hasJapaneseSource

    if let descriptor = Self.currentDescriptor() {
      current = InputSourceClassifier.kind(of: descriptor)
    }
    hasJapaneseSource = InputSourceClassifier.containsJapaneseSource(Self.enabledDescriptors())

    if current != previousKind || hasJapaneseSource != previousHasJapanese {
      onChange?()
    }
  }

  private func observe(_ name: CFString) {
    let observer = DistributedNotificationCenter.default().addObserver(
      forName: Notification.Name(name as String),
      object: nil,
      queue: .main
    ) { _ in
      MainActor.assumeIsolated { [weak self] in self?.refresh() }
    }
    observers.append(observer)
  }

  private static func currentDescriptor() -> InputSourceDescriptor? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
    return descriptor(of: source)
  }

  private static func enabledDescriptors() -> [InputSourceDescriptor] {
    guard
      let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue()
        as? [TISInputSource]
    else { return [] }
    return list.compactMap(descriptor(of:))
  }

  private static func descriptor(of source: TISInputSource) -> InputSourceDescriptor? {
    guard let idPointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
      return nil
    }
    let id = Unmanaged<CFString>.fromOpaque(idPointer).takeUnretainedValue() as String

    var languages: [String] = []
    if let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
      languages = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String] ?? []
    }
    return InputSourceDescriptor(id: id, languages: languages)
  }
}
