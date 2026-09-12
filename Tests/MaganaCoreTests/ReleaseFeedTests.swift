// ReleaseFeedTests.swift
// Verifies that a GitHub /releases/latest body becomes the release the update
// flow can act on, and that a body it cannot trust is refused by name (F-14).

import Foundation
import Testing

@testable import MaganaCore

@Suite("Release feed")
struct ReleaseFeedTests {

  /// The fields of a real `/releases/latest` response that the parser reads,
  /// plus one asset it must ignore.
  private func body(
    tag: String = "v1.1.0",
    assets: String =
      """
    [
      { "name": "Magana-1.1.0.zip",
        "browser_download_url": "https://example.com/Magana-1.1.0.zip",
        "size": 4194304 },
      { "name": "Magana-1.1.0.zip.sha256",
        "browser_download_url": "https://example.com/Magana-1.1.0.zip.sha256",
        "size": 96 }
    ]
    """
  ) -> Data {
    Data(
      """
      {
        "tag_name": "\(tag)",
        "name": "Magana 1.1.0",
        "body": "- 押して離したときの判定を修正しました\\n- 表示のちらつきを修正しました",
        "html_url": "https://github.com/senkentarou/magana/releases/tag/\(tag)",
        "published_at": "2026-09-20T02:30:00Z",
        "assets": \(assets)
      }
      """.utf8)
  }

  @Test("A release with a Magana-*.zip asset is read whole")
  func readsARelease() throws {
    let release = try ReleaseFeed.parseLatest(body(), assetPrefix: "Magana-")

    #expect(release.version == SemanticVersion(major: 1, minor: 1, patch: 0))
    #expect(release.tagName == "v1.1.0")
    #expect(release.assetName == "Magana-1.1.0.zip")
    #expect(release.assetSize == 4_194_304)
    #expect(release.downloadURL.absoluteString == "https://example.com/Magana-1.1.0.zip")
    #expect(release.notes.contains("押して離したときの判定を修正しました"))
    #expect(release.publishedAt != nil)
  }

  @Test("The first Magana-*.zip wins and other assets are ignored")
  func picksTheZip() throws {
    let assets =
      """
      [
        { "name": "SHASUMS", "browser_download_url": "https://example.com/SHASUMS", "size": 1 },
        { "name": "Magana-1.1.0.zip",
          "browser_download_url": "https://example.com/Magana-1.1.0.zip", "size": 2 }
      ]
      """
    let release = try ReleaseFeed.parseLatest(body(assets: assets), assetPrefix: "Magana-")

    #expect(release.assetName == "Magana-1.1.0.zip")
  }

  @Test("A release built for another app has no asset we can install")
  func refusesAForeignAsset() {
    let assets =
      """
      [
        { "name": "SomeOtherApp-1.1.0.zip",
          "browser_download_url": "https://example.com/SomeOtherApp-1.1.0.zip", "size": 1 }
      ]
      """
    #expect(throws: ReleaseFeedError.noAsset) {
      try ReleaseFeed.parseLatest(body(assets: assets), assetPrefix: "Magana-")
    }
  }

  @Test("A release with no assets at all is refused")
  func refusesNoAssets() {
    #expect(throws: ReleaseFeedError.noAsset) {
      try ReleaseFeed.parseLatest(body(assets: "[]"), assetPrefix: "Magana-")
    }
  }

  @Test("A tag that is not a version is refused, and says which tag")
  func refusesAnUnreadableTag() {
    #expect(throws: ReleaseFeedError.unreadableTag("nightly")) {
      try ReleaseFeed.parseLatest(body(tag: "nightly"), assetPrefix: "Magana-")
    }
  }

  @Test("A body missing tag_name is refused, and says which field")
  func refusesAMissingField() {
    let data = Data(#"{"html_url": "https://example.com", "assets": []}"#.utf8)
    #expect(throws: ReleaseFeedError.missingField("tag_name")) {
      try ReleaseFeed.parseLatest(data, assetPrefix: "Magana-")
    }
  }

  @Test("A response that is not JSON is refused")
  func refusesNonJSON() {
    #expect(throws: ReleaseFeedError.notJSON) {
      try ReleaseFeed.parseLatest(Data("<html>rate limited</html>".utf8), assetPrefix: "Magana-")
    }
  }

  @Test("Only a strictly newer release is offered")
  func offersOnlyNewer() throws {
    let release = try ReleaseFeed.parseLatest(body(), assetPrefix: "Magana-")

    #expect(release.isNewer(than: SemanticVersion(major: 1, minor: 0, patch: 9)))
    #expect(!release.isNewer(than: SemanticVersion(major: 1, minor: 1, patch: 0)))
    #expect(!release.isNewer(than: SemanticVersion(major: 1, minor: 2, patch: 0)))
  }
}
