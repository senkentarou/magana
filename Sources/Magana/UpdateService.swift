// UpdateService.swift
// The network half of F-14: read the latest release, fetch its zip.

import Foundation
import MaganaCore

/// Where the updater looks and what it will trust.
enum UpdateConfig {
  static let latestReleaseURL = URL(
    string: "https://api.github.com/repos/senkentarou/magana/releases/latest")!
  static let releasesPageURL = URL(
    string: "https://github.com/senkentarou/magana/releases")!
  /// The Developer ID team the replacement bundle must be signed by. Pinning
  /// the team is what makes the download safe to run: HTTPS proves the route,
  /// not the signer.
  ///
  /// A fork that ships its own releases has to change this together with
  /// `latestReleaseURL`. Changing only the URL leaves every download rejected
  /// as signed by another team, which reads as a broken updater rather than as
  /// a setting that was missed.
  static let teamID = "U2H8U2TN85"
  /// Release assets are named `Magana-<version>.zip` by `make release`.
  static let assetPrefix = "Magana-"
  static let userAgent = "Magana"
}

/// Everything that can go wrong between "check for updates" and a replaced
/// bundle. The cases are grouped by which of the three sentences the user
/// should see, not by which API failed; the detail goes to the trace.
enum UpdateError: Error {
  case network(any Error)
  case http(Int)
  case feed(ReleaseFeedError)
  case verify(String)
  case install(String)
}

/// Reads GitHub. Holds no state, so it is safe to make one per call.
struct UpdateService: Sendable {

  /// Fetches the latest release. No token and no header beyond the User-Agent
  /// GitHub asks for, so the request carries nothing about this machine
  ///.
  func fetchLatest() async throws -> ReleaseInfo {
    var request = URLRequest(url: UpdateConfig.latestReleaseURL)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue(UpdateConfig.userAgent, forHTTPHeaderField: "User-Agent")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw UpdateError.network(error)
    }
    try Self.checkStatus(of: response)

    do {
      return try ReleaseFeed.parseLatest(data, assetPrefix: UpdateConfig.assetPrefix)
    } catch let error as ReleaseFeedError {
      throw UpdateError.feed(error)
    }
  }

  /// Downloads the release asset into a fresh temporary directory and returns
  /// the zip's location. `progress` runs on a background thread.
  func download(
    _ release: ReleaseInfo,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> URL {
    var request = URLRequest(url: release.downloadURL)
    request.setValue(UpdateConfig.userAgent, forHTTPHeaderField: "User-Agent")

    let delegate = DownloadProgress(onProgress: progress)
    let downloaded: URL
    let response: URLResponse
    do {
      (downloaded, response) = try await URLSession.shared.download(
        for: request, delegate: delegate)
    } catch {
      throw UpdateError.network(error)
    }
    try Self.checkStatus(of: response)

    // The file URL that `download(for:delegate:)` hands back is only valid
    // until this function returns, so it is moved before anything else.
    let destination = try Self.makeTemporaryDirectory("Magana-Update")
      .appendingPathComponent(release.assetName)
    do {
      try FileManager.default.moveItem(at: downloaded, to: destination)
    } catch {
      throw UpdateError.install("cannot move download: \(error.localizedDescription)")
    }
    return destination
  }

  static func makeTemporaryDirectory(_ prefix: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
      throw UpdateError.install("cannot create \(url.path): \(error.localizedDescription)")
    }
    return url
  }

  private static func checkStatus(of response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200..<300).contains(http.statusCode) else {
      throw UpdateError.http(http.statusCode)
    }
  }
}

/// Turns `URLSession`'s byte counts into a 0...1 fraction.
///
/// A download delegate rather than iterating `URLSession.bytes`: the byte
/// stream would make the app count 4 MB one element at a time just to know how
/// far along it is.
private final class DownloadProgress: NSObject, URLSessionDownloadDelegate, Sendable {
  private let onProgress: @Sendable (Double) -> Void

  init(onProgress: @escaping @Sendable (Double) -> Void) {
    self.onProgress = onProgress
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard totalBytesExpectedToWrite > 0 else { return }
    onProgress(min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 1))
  }

  /// Required by the protocol. The async `download(for:delegate:)` call is the
  /// one that reports the finished file, so there is nothing to do here.
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {}
}
