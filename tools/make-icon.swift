// make-icon.swift
// Generates Resources/AppIcon.icns: the ⌘ in dark brown on a paper-coloured
// tile, banded top and bottom by suyari-gasumi. Run via `make icon`. The .icns is
// committed, so an ordinary build never runs this.
//
// Usage: swift tools/make-icon.swift <output-dir>
//
// The ⌘ geometry is a copy of MenuBarIcon's `CommandMark`, down to the two
// fractions it is built from. A script run by `swift <file>` cannot import the
// Magana target, so the two copies have to be changed together.

import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let iconsetDir = NSTemporaryDirectory() + "Magana.iconset"

/// The line weight, as a fraction of the mark's drawn extent.
let strokeFraction: CGFloat = 0.11
/// Each corner loop's radius, in the same fraction.
let loopFraction: CGFloat = 0.165

/// The ⌘ (U+2318): four three-quarter loops at the corners of a square, joined
/// by the square's own strokes. `size` is the extent the finished mark fills,
/// stroke included. The two fractions are chosen against the menu bar, where
/// the whole glyph is 16 pixels on a 1x display — see `CommandMark` in
/// `Sources/Magana/MenuBarIcon.swift` for why they are what they are.
func command(center: CGPoint, size: CGFloat) -> CGPath {
  let stroke = size * strokeFraction
  let loop = size * loopFraction
  // The loop centres sit at (±h, ±h). h is not free: the mark spans
  // 2 * (h + loop) + stroke, and that has to come out at `size`.
  let h = (size - stroke) / 2 - loop
  let m = CGAffineTransform(translationX: center.x, y: center.y)
  // y-down, so a decreasing angle turns the way `clockwise: true` names. Each
  // loop starts where the straight run before it ends, and `addArc` lays that
  // run down on the way in.
  let corners: [(center: CGPoint, start: CGFloat)] = [
    (CGPoint(x: h, y: h), .pi),
    (CGPoint(x: -h, y: h), -.pi / 2),
    (CGPoint(x: -h, y: -h), 0),
    (CGPoint(x: h, y: -h), .pi / 2),
  ]
  let path = CGMutablePath()
  path.move(to: CGPoint(x: h - loop, y: -h), transform: m)
  for corner in corners {
    path.addArc(
      center: corner.center, radius: loop, startAngle: corner.start,
      endAngle: corner.start - 3 * .pi / 2, clockwise: true, transform: m)
  }
  path.closeSubpath()
  return path
}

/// The palette, sampled from the Kyushu University exhibition poster
/// 「真仮名 ―仮名と文体の発達史―」. Magana is 真仮名, so the poster is about the
/// app's own namesake.
private enum Poster {
  static let koicha = srgb(0x51_36_25)  // 濃茶: the poster's manuscript, in shadow
  static let kusa = srgb(0x70_80_30)  // 深草
  static let moegi = srgb(0xB0_C0_60)  // 萌黄
  static let awa = srgb(0xC8_D0_88)  // 淡黄緑
  static let kinari = srgb(0xF0_F0_E8)  // 生成り: the paper
  static let kinariLow = srgb(0xE4_E6_D2)  // the same paper, in shadow

  static func srgb(_ hex: Int) -> CGColor {
    CGColor(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}

/// Draws the icon at `unit` points per canvas unit, in the same y-down space
/// the mark above is built in.
func draw(in ctx: CGContext, unit: CGFloat) {
  // Apple's icon grid: the tile covers 824 of the 1024pt canvas and the rest
  // stays transparent margin. That margin is what makes the icon sit at the
  // same size as the system's own apps in the Dock and in System Settings.
  let body = 824 * unit
  let tile = CGRect(x: 100 * unit, y: 100 * unit, width: body, height: body)
  let corner = body * 0.25
  let space = CGColorSpaceCreateDeviceRGB()

  /// One bar of the kasumi, in fractions of the tile. The corner radius is half
  /// the bar's height, which closes each end with a semicircle — the poster
  /// builds its clouds out of these, not out of a wavy band, and the difference
  /// is what keeps the shape from reading as seaweed. A bar whose extent leaves
  /// the tile is cut by the clip below, which is how the outermost bars end up
  /// flush with the edge.
  func bar(_ x0: CGFloat, _ x1: CGFloat, top: CGFloat, height: CGFloat, _ color: CGColor) {
    let rect = CGRect(
      x: tile.minX + tile.width * x0, y: tile.minY + tile.height * top,
      width: tile.width * (x1 - x0), height: tile.height * height)
    let radius = rect.height / 2
    ctx.saveGState()
    ctx.addPath(
      CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
  }

  ctx.saveGState()
  ctx.addPath(
    CGPath(roundedRect: tile, cornerWidth: corner, cornerHeight: corner, transform: nil))
  ctx.clip()

  // Paper, barely darker at the bottom. No gloss: the two sister apps have none,
  // and a highlight over a light ground only muddies it.
  guard
    let ground = CGGradient(
      colorsSpace: space, colors: [Poster.kinari, Poster.kinariLow] as CFArray, locations: nil)
  else { fatalError("could not build a gradient") }
  ctx.drawLinearGradient(
    ground, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])

  // Kasumi: a full-width band riding each edge, then two stepped bars inside it
  // with the middle one reaching furthest, which is what turns a staircase into
  // the swell of a cloud. Both groups stay clear of the mark, which spans
  // 0.24...0.76 of the tile.
  bar(-0.30, 1.30, top: -0.060, height: 0.115, Poster.awa)
  bar(-0.30, 0.62, top: 0.055, height: 0.062, Poster.moegi)
  bar(-0.30, 0.36, top: 0.117, height: 0.062, Poster.kusa)
  bar(-0.30, 1.30, top: 0.945, height: 0.115, Poster.awa)
  bar(0.38, 1.30, top: 0.883, height: 0.062, Poster.moegi)
  bar(0.64, 1.30, top: 0.821, height: 0.062, Poster.kusa)

  ctx.restoreGState()

  // The mark at 52% of the tile. Filling more of it would make Magana the one
  // loud icon in a row of system apps, which is what the design asks against.
  let size = body * 0.52
  ctx.addPath(command(center: CGPoint(x: tile.midX, y: tile.midY), size: size))
  ctx.setStrokeColor(Poster.koicha)
  ctx.setLineWidth(size * strokeFraction)
  ctx.setLineCap(.round)
  ctx.setLineJoin(.round)
  ctx.strokePath()
}

/// Renders one `px`×`px` PNG. The bitmap rep is built with explicit pixel
/// dimensions rather than through `NSImage`, whose backing follows the display
/// scale and would give 16pt sizes a 32px image.
func renderIcon(px: Int) -> Data {
  guard
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0),
    let context = NSGraphicsContext(bitmapImageRep: rep)
  else { fatalError("could not allocate a \(px)px bitmap") }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  let ctx = context.cgContext
  ctx.translateBy(x: 0, y: CGFloat(px))
  ctx.scaleBy(x: 1, y: -1)
  draw(in: ctx, unit: CGFloat(px) / 1024)
  NSGraphicsContext.restoreGraphicsState()

  guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encode failed at \(px)px")
  }
  return png
}

try? FileManager.default.removeItem(atPath: iconsetDir)
try FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// The sizes `iconutil` expects, at 1x and 2x.
let specs: [(name: String, px: Int)] = [
  ("icon_16x16", 16), ("icon_16x16@2x", 32),
  ("icon_32x32", 32), ("icon_32x32@2x", 64),
  ("icon_128x128", 128), ("icon_128x128@2x", 256),
  ("icon_256x256", 256), ("icon_256x256@2x", 512),
  ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for spec in specs {
  try renderIcon(px: spec.px).write(to: URL(fileURLWithPath: "\(iconsetDir)/\(spec.name).png"))
}

let icnsPath = "\(outDir)/AppIcon.icns"
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir, "-o", icnsPath]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
  fatalError("iconutil exited with \(iconutil.terminationStatus)")
}
print("wrote \(icnsPath)")
