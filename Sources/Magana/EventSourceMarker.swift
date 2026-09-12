// EventSourceMarker.swift
// The stamp this app puts on the events it creates.

/// Written to `CGEventSource.userData` by `Switcher` and read back by the event
/// tap, so the app can tell its own 英数 / かな keys from the user's typing.
///
/// It lives outside both types because the tap callback is a C function with no
/// actor isolation, and a `static let` on a `@MainActor` type is not reachable
/// from there. The value is arbitrary; it only has to be unlikely to collide
/// with another app's marker.
enum EventSourceMarker {
  static let magana: Int64 = 0x4D41_4741_4E41  // "MAGANA"
}
