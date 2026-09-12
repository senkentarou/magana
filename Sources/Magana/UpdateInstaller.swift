// UpdateInstaller.swift
// Hands the bundle swap to a detached shell helper, because a running .app
// cannot overwrite itself.

import AppKit
import Foundation

/// Writes and launches the helper that replaces this app once it has quit.
enum UpdateInstaller {

  /// The helper waits for `pid` to disappear, swaps `destination` for
  /// `newApp`, and relaunches. It keeps the old bundle aside until the copy
  /// succeeds so a failed swap leaves the user with the app they had
  /// .
  ///
  /// When `/Applications` is not writable the swap is re-run through
  /// `osascript` as an administrator; if that prompt is declined the verified
  /// bundle is revealed in Finder rather than discarded.
  private static let script = """
    #!/bin/sh
    # Argument forms:
    #   <pid> <new app> <destination> <0|1 needs admin>   the detached waiter
    #   swap <new app> <destination> <owner>              the swap itself
    set -u

    # Returns rather than exits: an exit here would end the script and skip
    # the "reveal it in Finder" fallback the caller falls back to.
    swap() {
      NEW_APP="$1"; DEST="$2"; OWNER="$3"
      BACKUP="$DEST.magana-old"
      rm -rf "$BACKUP"
      if [ -e "$DEST" ]; then mv "$DEST" "$BACKUP" || return 1; fi
      if /usr/bin/ditto "$NEW_APP" "$DEST"; then
        chown -R "$OWNER" "$DEST" 2>/dev/null
        rm -rf "$BACKUP"
      else
        rm -rf "$DEST"
        if [ -e "$BACKUP" ]; then mv "$BACKUP" "$DEST"; fi
        return 1
      fi
      return 0
    }

    if [ "$1" = "swap" ]; then shift; swap "$@"; exit $?; fi

    OLD_PID="$1"; NEW_APP="$2"; DEST="$3"; NEED_ADMIN="$4"; SELF="$0"
    while kill -0 "$OLD_PID" 2>/dev/null; do sleep 0.2; done
    OWNER=$(id -un)

    if [ "$NEED_ADMIN" = "1" ]; then
      CMD="/bin/sh '$SELF' swap '$NEW_APP' '$DEST' '$OWNER'"
      PROMPT="do shell script \\"$CMD\\" with administrator privileges"
      if ! osascript -e "$PROMPT"; then open -R "$NEW_APP"; exit 1; fi
    else
      if ! swap "$NEW_APP" "$DEST" "$OWNER"; then open -R "$NEW_APP"; exit 1; fi
    fi

    # The extracted copy has served its purpose once ditto has read it. Only on
    # the path that got here — the failure paths above reveal it in Finder and
    # leave it for the user. The helper's own directory stays: a sh script that
    # deletes the file it is still reading is a race for a few KB.
    rm -rf "$(dirname "$NEW_APP")"
    open "$DEST"
    """

  /// Starts the helper. The caller must terminate the app right after this
  /// returns — the helper is already counting on this process to go away.
  static func launchHelper(newApp: URL, replacing destination: URL) throws {
    let directory = try UpdateService.makeTemporaryDirectory("Magana-Helper")
    let helper = directory.appendingPathComponent("update_helper.sh")
    do {
      try script.write(to: helper, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: helper.path)
    } catch {
      throw UpdateError.install("cannot write helper: \(error.localizedDescription)")
    }

    let needsAdmin = !FileManager.default.isWritableFile(
      atPath: destination.deletingLastPathComponent().path)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
      helper.path,
      String(ProcessInfo.processInfo.processIdentifier),
      newApp.path,
      destination.path,
      needsAdmin ? "1" : "0",
    ]
    do {
      // Launched, not awaited: it outlives this process on purpose.
      try process.run()
    } catch {
      throw UpdateError.install("cannot start helper: \(error.localizedDescription)")
    }
  }
}
