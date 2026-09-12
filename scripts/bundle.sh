#!/bin/bash
# Builds build/Magana.app from the SPM executable.
#
# Xcode is not involved: what is needed is a signed, launchable .app, and
# nothing else a project file would provide. `make release` runs notarytool
# against what this script builds.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-release}"
APP="build/Magana.app"
# TCC identifies an app by its code signature. An ad-hoc signature ("-") is
# different on every build, so macOS would treat each rebuild as a new app and
# drop the Accessibility grant — every rebuild would need the permission dance
# again, which makes F-1..F-6 untestable. Signing with the stable Developer ID
# keeps the grant across rebuilds. Override with CODESIGN_IDENTITY=- if you do
# not have the certificate.
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Masahiro Senda (U2H8U2TN85)}"

# -warnings-as-errors here as well as in `make build`: the gate builds debug,
# but this is the configuration that ships. Release uses whole-module
# optimization, so it can diagnose what per-file debug compilation cannot,
# and without this flag the first place that shows up is `make release`.
swift build -c "$CONFIGURATION" -Xswiftc -warnings-as-errors --product Magana
BINARY="$(swift build -c "$CONFIGURATION" --product Magana --show-bin-path)/Magana"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Magana"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Committed artwork, not a build product: `make icon` regenerates it.
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# The licence travels with the binary, not just with the repository. GPL-3.0 §4
# asks for a copy of the licence alongside every copy of the program, and the
# .zip a release hands to someone else is a copy that carries no repository.
cp LICENSE "$APP/Contents/Resources/LICENSE"

# A secure timestamp is a round trip to Apple's timestamp server: a rebuild
# does not need one and cannot get one offline, but notarization refuses a
# signature without it. `make release` overrides this with --timestamp.
CODESIGN_TIMESTAMP="${CODESIGN_TIMESTAMP:---timestamp=none}"

# Hardened runtime is what a Developer ID build is expected to carry, and
# turning it on here means the signing flags are settled once.
codesign --force --options runtime "$CODESIGN_TIMESTAMP" \
	--sign "$CODESIGN_IDENTITY" "$APP"
codesign --verify --verbose=2 "$APP"

echo "built $APP"
