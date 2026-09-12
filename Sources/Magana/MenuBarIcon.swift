// MenuBarIcon.swift
// The menu bar glyph: the ⌘, alone, dimmed while the app is paused.
//
// Drawn here rather than shipped as artwork so the one thing on screen at every
// moment stays crisp at whatever point size the menu bar asks for, and so there
// is no image resource for `scripts/bundle.sh` to keep in step. The ⌘ geometry
// also exists in `tools/make-icon.swift`; a script run by `swift <file>` cannot
// import this target, so the two copies have to be changed together.
//
// The mark carried an arrow badge naming the ⌘ that reaches the current input
// source until 2026-09-07. Two passes at which ⌘ it should point at still left
// it wrong on the machine, and there is no room in 18pt for both a readable
// arrow and an uncut ⌘, so the input source moved to the menu's status line and
// the icon kept only what it can say at that size.

import AppKit

enum MenuBarIcon {

  /// `paused` is F-11: neither ⌘ does anything, and a faded glyph is how macOS
  /// says "this control is not doing anything".
  static func image(paused: Bool) -> NSImage {
    let size = NSSize(width: canvasSize, height: canvasSize)
    let image = NSImage(size: size, flipped: true) { bounds in
      draw(paused: paused, in: bounds)
      return true
    }
    // Template: macOS paints the alpha we lay down, in whatever colour the menu
    // bar is using.
    image.isTemplate = true
    return image
  }

  // MARK: - Layout

  /// The design space, in points, y down. 18 square is what AppKit hands a
  /// `MenuBarExtra` label.
  private static let canvasSize: CGFloat = 18

  /// Nothing cuts into the mark any more, so it takes the whole canvas bar a
  /// point of air on each side.
  private static let markSize: CGFloat = 16
  private static let markCenter = CGPoint(x: 9, y: 9)

  // MARK: - Drawing

  private static func draw(paused: Bool, in bounds: NSRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    let scale = min(bounds.width / canvasSize, bounds.height / canvasSize)
    let placement = CGAffineTransform(
      translationX: bounds.minX + (bounds.width - canvasSize * scale) / 2,
      y: bounds.minY + (bounds.height - canvasSize * scale) / 2
    ).scaledBy(x: scale, y: scale)

    ctx.setStrokeColor(NSColor.black.withAlphaComponent(paused ? 0.4 : 1).cgColor)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(CommandMark.path(center: markCenter, size: markSize, in: placement))
    ctx.setLineWidth(CommandMark.stroke(for: markSize) * scale)
    ctx.strokePath()
  }
}

/// The ⌘ (U+2318), drawn to this app's own proportions.
///
/// The symbol is four three-quarter loops at the corners of a square, joined by
/// the square's own strokes. What is left to choose is how big the loops are
/// against the square and how heavy the line is, and the two ends of the app
/// pull opposite ways: the menu bar draws the mark at 16pt, which is 16 pixels
/// for the whole glyph on a 1x display, while the app icon runs to 512 in the
/// Dock and wants a line with some weight behind it.
///
/// Opening the loops is what settles it. The hole inside a loop is
/// `2 * loop - stroke`, so widening the loop buys room the stroke can then
/// spend: at these numbers the hole is 22% of the extent, 3.5px at 16pt, while
/// the line is heavier than a tighter mark could afford. Going further opens
/// the loops at the cost of the middle — the straight runs shorten until the
/// mark reads as a four-petal flower rather than a ⌘ — which is what holds
/// `loop` at 16.5% and keeps the loop centres 1.7 radii apart.
///
/// Shared by the menu bar and `tools/make-icon.swift`, which cannot import this
/// target and carries its own copy — change the two together.
enum CommandMark {

  /// The line weight, as a fraction of the mark's drawn extent.
  private static let strokeFraction: CGFloat = 0.11
  /// Each corner loop's radius, in the same fraction.
  private static let loopFraction: CGFloat = 0.165

  /// The line weight for a mark drawn at `size`.
  static func stroke(for size: CGFloat) -> CGFloat { size * strokeFraction }

  /// `size` is the extent the finished mark fills, stroke included.
  static func path(center: CGPoint, size: CGFloat, in placement: CGAffineTransform = .identity)
    -> CGPath
  {
    let stroke = size * strokeFraction
    let loop = size * loopFraction
    // The loop centres sit at (±h, ±h). h is not free: the mark spans
    // 2 * (h + loop) + stroke, and that has to come out at `size`.
    let h = (size - stroke) / 2 - loop
    let m = CGAffineTransform(translationX: center.x, y: center.y).concatenating(placement)
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
}
