// UpdateBundle.swift
// Unpacks a downloaded release and refuses to hand back anything this app did
// not sign.

import Foundation
import MaganaCore
import Security

/// Extraction and signature checking for a downloaded update.
enum UpdateBundle {

  /// Unzips `zip` into a fresh directory and returns the `.app` inside it.
  ///
  /// `ditto` rather than `Archive.unzip` or `NSFileManager`: it is the tool
  /// that preserves the extended attributes and symlinks a signed bundle needs,
  /// and a bundle that loses them fails the signature check that follows.
  static func extract(zip: URL) throws -> URL {
    let directory = try UpdateService.makeTemporaryDirectory("Magana-Extract")

    let ditto = Process()
    ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    ditto.arguments = ["-x", "-k", zip.path, directory.path]
    let errors = Pipe()
    ditto.standardError = errors

    do {
      try ditto.run()
    } catch {
      throw UpdateError.install("ditto did not start: \(error.localizedDescription)")
    }
    // Read before waiting: a full pipe buffer would block ditto forever.
    let errorText =
      String(
        data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    ditto.waitUntilExit()

    guard ditto.terminationStatus == 0 else {
      throw UpdateError.install("ditto exited \(ditto.terminationStatus): \(errorText)")
    }

    let entries = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    guard let app = entries.first(where: { $0.hasSuffix(".app") }) else {
      throw UpdateError.install("no .app in \(directory.path)")
    }
    return directory.appendingPathComponent(app)
  }

  /// Checks that the extracted bundle is the release it claims to be.
  ///
  /// Two things have to hold before the app will replace itself: the bundle is
  /// signed by our Developer ID team, and its `CFBundleShortVersionString`
  /// matches the tag the API advertised. The first is the security check; the
  /// second catches a release whose tag and payload were built from different
  /// commits.
  static func verify(app: URL, expecting version: SemanticVersion) throws {
    var staticCodeOrNil: SecStaticCode?
    let created = SecStaticCodeCreateWithPath(app as CFURL, SecCSFlags(), &staticCodeOrNil)
    guard created == errSecSuccess, let staticCode = staticCodeOrNil else {
      throw UpdateError.verify("SecStaticCodeCreateWithPath failed: \(created)")
    }

    // `anchor apple generic` alone would accept any Developer ID, so the leaf
    // certificate's OU — our team — is part of the requirement.
    let requirementText =
      "anchor apple generic and certificate leaf[subject.OU] = \"\(UpdateConfig.teamID)\""
    var requirementOrNil: SecRequirement?
    let compiled = SecRequirementCreateWithString(
      requirementText as CFString, SecCSFlags(), &requirementOrNil)
    guard compiled == errSecSuccess, let requirement = requirementOrNil else {
      throw UpdateError.verify("SecRequirementCreateWithString failed: \(compiled)")
    }

    var errorOrNil: Unmanaged<CFError>?
    let checked = SecStaticCodeCheckValidityWithErrors(
      staticCode,
      SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode),
      requirement,
      &errorOrNil)
    guard checked == errSecSuccess else {
      let detail =
        errorOrNil?.takeRetainedValue().localizedDescription ?? "status \(checked)"
      throw UpdateError.verify(detail)
    }

    guard let plistData = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
      let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil)
        as? [String: Any],
      let shortVersion = plist["CFBundleShortVersionString"] as? String
    else {
      throw UpdateError.verify("cannot read CFBundleShortVersionString")
    }
    guard let bundleVersion = SemanticVersion(shortVersion), bundleVersion == version else {
      throw UpdateError.verify("bundle says \(shortVersion), release says \(version)")
    }
  }
}
