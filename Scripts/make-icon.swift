// Renders the DNSwitch app icon into DNSwitch/Assets.xcassets/AppIcon.appiconset.
// Run from the project root:  swift Scripts/make-icon.swift
import AppKit

let canvas: CGFloat = 1024

func render(size px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: 824pt body, centered, with a soft drop shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(shape)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient: bright azure at top to deep indigo at bottom.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let colors = [NSColor(srgbRed: 0.20, green: 0.66, blue: 1.00, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.16, green: 0.33, blue: 0.93, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.24, green: 0.14, blue: 0.62, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Subtle top highlight.
    let shine = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor.white.withAlphaComponent(0.22).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                           locations: [0, 1])!
    ctx.drawRadialGradient(shine, startCenter: CGPoint(x: 512, y: 980), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 980), endRadius: 560, options: [])
    ctx.restoreGState()

    // Wi-Fi arcs, centered on a point near the lower middle.
    let center = CGPoint(x: 512, y: 430)
    let start = CGFloat.pi * 0.25, end = CGFloat.pi * 0.75
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineCap(.round)
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor.black.withAlphaComponent(0.22).cgColor)
    for (radius, width) in [(330.0, 62.0), (225.0, 62.0), (120.0, 62.0)] {
        ctx.setLineWidth(width)
        ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        ctx.strokePath()
    }
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 44, y: center.y - 44, width: 88, height: 88))

    // "DNS" pill below the arcs.
    let pill = CGRect(x: 312, y: 190, width: 400, height: 150)
    ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 75, cornerHeight: 75, transform: nil))
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    let font = NSFont.systemFont(ofSize: 104, weight: .heavy)
    let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 104) } ?? font
    let text = NSAttributedString(string: "DNS", attributes: [
        .font: rounded,
        .foregroundColor: NSColor(srgbRed: 0.18, green: 0.28, blue: 0.85, alpha: 1),
        .kern: 4,
    ])
    let ts = text.size()
    text.draw(at: CGPoint(x: pill.midX - ts.width / 2, y: pill.midY - ts.height / 2 + 4))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: "DNSwitch/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(size: points * scale).write(to: dir.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: dir.appendingPathComponent("Contents.json"))
try #"{ "info" : { "author" : "xcode", "version" : 1 } }"#
    .write(to: URL(fileURLWithPath: "DNSwitch/Assets.xcassets/Contents.json"), atomically: true, encoding: .utf8)
print("Wrote \(images.count) icon images to \(dir.path)")
