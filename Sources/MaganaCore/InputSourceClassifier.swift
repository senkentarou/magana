// InputSourceClassifier.swift
// Turns a macOS input source into the one bit this app cares about: is the user
// typing Japanese right now?

/// The facts about an input source that classification needs.
public struct InputSourceDescriptor: Sendable, Equatable {
  public let id: String
  public let languages: [String]

  public init(id: String, languages: [String]) {
    self.id = id
    self.languages = languages
  }
}

public enum InputSourceClassifier {
  /// A Japanese IME in its Roman mode is still a Japanese input source as far
  /// as `kTISPropertyInputSourceLanguages` is concerned, so language alone
  /// cannot answer this — `com.apple.inputmethod.Kotoeri.RomajiTyping.Roman`
  /// and `...RomajiTyping.Japanese` both report `ja`. The mode is the suffix,
  /// and every Japanese IME that ships a direct-input mode spells it `.Roman`.
  ///
  /// Matching the suffix rather than searching for "Roman" anywhere matters:
  /// the かな mode of the romaji layout is `...RomajiTyping.Japanese`, which
  /// contains "Roman" inside "RomajiTyping".
  public static func kind(of source: InputSourceDescriptor) -> InputSourceKind {
    guard source.languages.contains("ja") else { return .eisuu }
    return source.id.hasSuffix(".Roman") ? .eisuu : .kana
  }

  /// Whether any of these sources can put the user into kana. When none can,
  /// the かな side of the app has nowhere to go and says so.
  public static func containsJapaneseSource(_ sources: [InputSourceDescriptor]) -> Bool {
    sources.contains { kind(of: $0) == .kana }
  }
}
