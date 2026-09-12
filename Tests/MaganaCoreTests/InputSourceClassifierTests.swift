// InputSourceClassifierTests.swift
// Verifies the 英数 / かな reading of real macOS input source identifiers.

import Testing

@testable import MaganaCore

@Suite("Input source classification")
struct InputSourceClassifierTests {

  @Test(
    "Japanese IME modes read as かな, their Roman modes as 英数",
    arguments: [
      ("com.apple.keylayout.ABC", ["en"], InputSourceKind.eisuu),
      ("com.apple.keylayout.US", ["en"], InputSourceKind.eisuu),
      ("com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", ["ja"], InputSourceKind.kana),
      ("com.apple.inputmethod.Kotoeri.RomajiTyping.Roman", ["ja"], InputSourceKind.eisuu),
      ("com.apple.inputmethod.Kotoeri.KanaTyping.Japanese", ["ja"], InputSourceKind.kana),
      ("com.apple.inputmethod.Kotoeri.KanaTyping.Roman", ["ja"], InputSourceKind.eisuu),
      ("com.google.inputmethod.Japanese.base", ["ja"], InputSourceKind.kana),
      ("com.google.inputmethod.Japanese.Roman", ["ja"], InputSourceKind.eisuu),
    ]
  )
  func classification(id: String, languages: [String], expected: InputSourceKind) {
    #expect(InputSourceClassifier.kind(of: .init(id: id, languages: languages)) == expected)
  }

  @Test("A machine with no Japanese IME has nowhere for かな to go")
  func noJapaneseSource() {
    let sources = [
      InputSourceDescriptor(id: "com.apple.keylayout.ABC", languages: ["en"]),
      InputSourceDescriptor(id: "com.apple.keylayout.German", languages: ["de"]),
    ]
    #expect(InputSourceClassifier.containsJapaneseSource(sources) == false)
  }

  @Test("A Japanese IME being enabled is enough, whichever mode is current")
  func hasJapaneseSource() {
    let sources = [
      InputSourceDescriptor(id: "com.apple.keylayout.ABC", languages: ["en"]),
      InputSourceDescriptor(
        id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman", languages: ["ja"]),
      InputSourceDescriptor(
        id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", languages: ["ja"]),
    ]
    #expect(InputSourceClassifier.containsJapaneseSource(sources))
  }
}
