// swift-tools-version: 6.0
import PackageDescription

// MaganaCore holds every decision the app makes; Magana holds every API call it
// makes. The split is what lets `swift test` cover the alone-press judgement
// without a TCC grant, an event tap, or a connected display.
let package = Package(
  name: "Magana",
  platforms: [.macOS(.v14)],
  targets: [
    .target(
      name: "MaganaCore",
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .executableTarget(
      name: "Magana",
      dependencies: ["MaganaCore"],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .testTarget(
      name: "MaganaCoreTests",
      dependencies: ["MaganaCore"],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
  ]
)
