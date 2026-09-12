// SemanticVersionTests.swift
// Verifies that a release tag is read the way F-14 needs it: only the two
// shapes we publish parse, and "newer" orders the way a human reads it.

import Testing

@testable import MaganaCore

@Suite("Semantic version")
struct SemanticVersionTests {

  @Test("A plain and a v-prefixed tag parse to the same version")
  func parsesBothTagShapes() {
    #expect(SemanticVersion("1.2.3") == SemanticVersion(major: 1, minor: 2, patch: 3))
    #expect(SemanticVersion("v1.2.3") == SemanticVersion(major: 1, minor: 2, patch: 3))
  }

  @Test("Components are compared as numbers, not as text")
  func ordersByNumber() {
    #expect(SemanticVersion("1.10.0")! > SemanticVersion("1.9.0")!)
    #expect(SemanticVersion("2.0.0")! > SemanticVersion("1.99.99")!)
    #expect(SemanticVersion("1.0.1")! > SemanticVersion("1.0.0")!)
    #expect(!(SemanticVersion("1.0.0")! > SemanticVersion("1.0.0")!))
  }

  @Test(
    "Anything that is not major.minor.patch is refused",
    arguments: [
      "1.2", "1.2.3.4", "1.2.x", "", "v", "1..3", "1.2.-3", "1.2.+3", " 1.2.3", "1.2.3-beta",
      "１.２.３",
    ])
  func refusesOtherShapes(_ text: String) {
    #expect(SemanticVersion(text) == nil)
  }

  @Test("The description round-trips through the parser")
  func describesItself() {
    #expect(SemanticVersion("v0.10.2")!.description == "0.10.2")
  }
}
