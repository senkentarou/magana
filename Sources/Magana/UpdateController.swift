// UpdateController.swift
// The one place that knows where the update is in its journey (F-14).

import AppKit
import Foundation
import MaganaCore

@MainActor
final class UpdateController: ObservableObject {

  /// Where the update is. The menu shows a row only in `.available`; every
  /// other case is either invisible or lives in the update window.
  enum Phase: Equatable {
    case idle
    case checking
    case upToDate
    case available(ReleaseInfo)
    case downloading(Double)
    case verifying
    case installing
    /// The message, and whether checking again is the thing to try. Only a
    /// failed check can be retried from here; a download or a swap that
    /// failed sends the reader to the release page instead.
    case failed(String, canCheckAgain: Bool)
  }

  /// The running bundle's version. A bundle that does not say is treated as
  /// 0.0.0, so the first release still reads as newer.
  static let currentVersion =
    SemanticVersion(AppVersion.short) ?? SemanticVersion(major: 0, minor: 0, patch: 0)

  /// Long enough that a login-item launch is not racing the rest of the
  /// desktop coming up, short enough that F-14's "起動時に通知" still holds.
  private static let firstCheckDelay: Duration = .seconds(10)
  private static let checkInterval: Duration = .seconds(24 * 60 * 60)

  @Published private(set) var phase: Phase = .idle
  /// The last release the check saw, newer or not, so the release page can be
  /// opened from a window that is showing "最新です".
  @Published private(set) var latest: ReleaseInfo?

  /// Read at the moment of each automatic check rather than captured once:
  /// the toggle it reflects lives in `Settings` and can change while the app
  /// runs.
  var isAutoCheckEnabled: () -> Bool = { true }

  private let service = UpdateService()
  private var loop: Task<Void, Never>?
  private var isBusy = false

  // MARK: - Lifecycle

  /// Starts the automatic check. Calling it twice does nothing the second
  /// time, matching how `AppController.start()` guards itself.
  func start() {
    guard loop == nil else { return }
    loop = Task { [weak self] in
      try? await Task.sleep(for: Self.firstCheckDelay)
      while !Task.isCancelled {
        guard let self else { return }
        self.check(userInitiated: false)
        try? await Task.sleep(for: Self.checkInterval)
      }
    }
  }

  // MARK: - Actions

  func check(userInitiated: Bool) {
    guard userInitiated || isAutoCheckEnabled() else { return }
    guard !isBusy else { return }
    isBusy = true

    let previous = phase
    phase = .checking

    Task {
      defer { isBusy = false }
      do {
        let release = try await service.fetchLatest()
        latest = release
        phase = release.isNewer(than: Self.currentVersion) ? .available(release) : .upToDate
        Diagnostics.trace(
          "update check: latest \(release.version), running \(Self.currentVersion)")
      } catch {
        Diagnostics.trace("update check failed: \(error)")
        // A check nobody asked for goes back to what it was showing. Failing
        // in the menu bar would be a notification the user did not request
        //.
        phase =
          userInitiated ? .failed(Message.checkFailed, canCheckAgain: true) : previous
      }
    }
  }

  /// Downloads the available release, verifies it, and quits so the helper can
  /// put it in place.
  func installAvailable() {
    guard case .available(let release) = phase, !isBusy else { return }
    isBusy = true

    Task {
      defer { isBusy = false }
      // Each of these is a fresh directory under the temporary directory, and
      // an update that fails partway through would otherwise leave the whole
      // download behind. The helper deletes the extracted copy after the swap,
      // because it is still reading from it when this process quits.
      var zipDirectory: URL?
      var extractDirectory: URL?
      func discardTemporaries() {
        for url in [zipDirectory, extractDirectory].compactMap({ $0 }) {
          try? FileManager.default.removeItem(at: url)
        }
      }

      do {
        phase = .downloading(0)
        let zip = try await service.download(release) { [weak self] fraction in
          Task { @MainActor in self?.phase = .downloading(fraction) }
        }
        zipDirectory = zip.deletingLastPathComponent()

        phase = .verifying
        // Off the main actor: `ditto` and the signature check are file work,
        // and the menu bar has to stay responsive while they run.
        let app = try await Task.detached {
          let app = try UpdateBundle.extract(zip: zip)
          try UpdateBundle.verify(app: app, expecting: release.version)
          return app
        }.value
        extractDirectory = app.deletingLastPathComponent()

        phase = .installing
        try UpdateInstaller.launchHelper(newApp: app, replacing: Bundle.main.bundleURL)
        // The zip is done with; the extracted copy is not, so it is left for
        // the helper.
        try? FileManager.default.removeItem(at: zip.deletingLastPathComponent())
        Diagnostics.trace("update \(release.version) staged, quitting for the swap")
        NSApp.terminate(nil)
      } catch {
        discardTemporaries()
        Diagnostics.trace("update install failed: \(error)")
        phase = .failed(Self.message(for: error), canCheckAgain: false)
      }
    }
  }

  func openReleasePage() {
    NSWorkspace.shared.open(latest?.pageURL ?? UpdateConfig.releasesPageURL)
  }

  // MARK: - Wording

  /// Two sentences, "何が起きた。どうすればよい".
  private enum Message {
    static let checkFailed = "アップデートを確認できませんでした。接続を確かめてもう一度お試しください"
    static let downloadFailed = "アップデートをダウンロードできませんでした。接続を確かめてもう一度お試しください"
    static let verifyFailed = "ダウンロードした Magana を確認できませんでした。GitHub のリリースページから手動で入れ替えてください"
    static let installFailed = "更新を適用できませんでした。GitHub のリリースページから手動で入れ替えてください"
  }

  /// Only the install path uses this; a failed check writes its own sentence.
  private static func message(for error: any Error) -> String {
    guard let error = error as? UpdateError else { return Message.installFailed }
    switch error {
    case .network, .http: return Message.downloadFailed
    case .verify: return Message.verifyFailed
    case .feed, .install: return Message.installFailed
    }
  }
}
