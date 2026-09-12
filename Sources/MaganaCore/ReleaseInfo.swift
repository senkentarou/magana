// ReleaseInfo.swift
// One GitHub release, and the pure parse that turns the API's JSON into it.

import Foundation

/// Everything the update flow needs to know about a published release.
public struct ReleaseInfo: Equatable, Sendable {
  public let version: SemanticVersion
  public let tagName: String
  /// The release body, as written on GitHub. Shown as-is in the update window.
  public let notes: String
  public let pageURL: URL
  public let downloadURL: URL
  public let assetName: String
  public let assetSize: Int64
  public let publishedAt: Date?

  public init(
    version: SemanticVersion,
    tagName: String,
    notes: String,
    pageURL: URL,
    downloadURL: URL,
    assetName: String,
    assetSize: Int64,
    publishedAt: Date?
  ) {
    self.version = version
    self.tagName = tagName
    self.notes = notes
    self.pageURL = pageURL
    self.downloadURL = downloadURL
    self.assetName = assetName
    self.assetSize = assetSize
    self.publishedAt = publishedAt
  }

  /// Whether this release is worth offering to someone running `current`.
  ///
  /// Strictly newer, so re-running the same version — or a local build that is
  /// ahead of the last release — never offers an update.
  public func isNewer(than current: SemanticVersion) -> Bool {
    version > current
  }
}

/// What a release feed can fail to be. Each case names the thing that was
/// missing so the trace says which end of the pipe is wrong.
public enum ReleaseFeedError: Error, Equatable {
  case notJSON
  case missingField(String)
  case unreadableTag(String)
  case noAsset
}

/// Reads GitHub's `/releases/latest` response.
///
/// This lives in `MaganaCore` rather than next to the `URLSession` call so the
/// shape of the response can be tested without a network — the parse is the
/// part that breaks when GitHub changes a field, and the fetch is the part
/// that cannot be exercised in `swift test` at all.
public enum ReleaseFeed {
  /// Parses one `/releases/latest` body.
  ///
  /// - Parameter assetPrefix: the leading part of the asset file name to look
  ///   for. Assets are matched by `<prefix>*.zip` rather than by an exact name
  ///   so the version in the file name does not have to be reconstructed here.
  public static func parseLatest(_ data: Data, assetPrefix: String) throws -> ReleaseInfo {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ReleaseFeedError.notJSON
    }

    guard let tagName = root["tag_name"] as? String else {
      throw ReleaseFeedError.missingField("tag_name")
    }
    guard let version = SemanticVersion(tagName) else {
      throw ReleaseFeedError.unreadableTag(tagName)
    }
    guard let pageURLString = root["html_url"] as? String,
      let pageURL = URL(string: pageURLString)
    else {
      throw ReleaseFeedError.missingField("html_url")
    }

    guard let assets = root["assets"] as? [[String: Any]],
      let asset = assets.first(where: {
        guard let name = $0["name"] as? String else { return false }
        return name.hasPrefix(assetPrefix) && name.hasSuffix(".zip")
      })
    else {
      throw ReleaseFeedError.noAsset
    }
    guard let assetName = asset["name"] as? String,
      let downloadURLString = asset["browser_download_url"] as? String,
      let downloadURL = URL(string: downloadURLString)
    else {
      throw ReleaseFeedError.missingField("assets[].browser_download_url")
    }

    return ReleaseInfo(
      version: version,
      tagName: tagName,
      notes: (root["body"] as? String) ?? "",
      pageURL: pageURL,
      downloadURL: downloadURL,
      assetName: assetName,
      assetSize: (asset["size"] as? Int64) ?? Int64(asset["size"] as? Int ?? 0),
      publishedAt: (root["published_at"] as? String).flatMap {
        ISO8601DateFormatter().date(from: $0)
      }
    )
  }
}
