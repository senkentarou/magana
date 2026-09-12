// CommandKeyMonitor.swift
// Which ⌘ is being held right now, for the key caps in the settings window.

import Combine
import MaganaCore

/// The live up/down state of the two ⌘ keys.
///
/// Its own observable object rather than a property on `AppController`: this
/// changes on every ⌘ press, and publishing from the controller would
/// invalidate every view watching it — the menu bar extra included — for a fact
/// only the settings window cares about.
///
/// The set itself is `MaganaCore.HeldCommandKeys`; this only republishes it.
@MainActor
final class CommandKeyMonitor: ObservableObject {
  @Published private(set) var keys = HeldCommandKeys()

  var held: Set<CommandSide> { keys.sides }

  func handle(_ event: DetectorEvent) {
    keys.handle(event)
  }

  /// Clears the lit caps. Called when the tap stops, since a key released while
  /// the app was not watching would otherwise stay lit for good.
  func reset() {
    keys.reset()
  }
}
