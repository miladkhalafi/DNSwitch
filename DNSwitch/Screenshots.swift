import AppKit
import SwiftUI

/// Made-up data for README screenshots, so real network names never show up.
enum DemoData {
    static let ssid = "Home"
    static let applied = ["1.1.1.1", "1.0.0.1"]

    static var settings: AppSettings {
        var s = AppSettings()
        s.rules = [
            NetworkRule(ssid: "Home", servers: "1.1.1.1, 1.0.0.1"),
            NetworkRule(ssid: "Office", servers: "10.0.0.53"),
            NetworkRule(ssid: "Coffee Shop", servers: "9.9.9.9, 149.112.112.112", enabled: false),
        ]
        s.otherNetworksServers = "8.8.8.8, 8.8.4.4"
        return s
    }

    static var log: [AppState.LogEntry] {
        let now = Date()
        func entry(_ minutesAgo: Double, _ text: String) -> AppState.LogEntry {
            var e = AppState.LogEntry(text: text)
            e.date = now.addingTimeInterval(-minutesAgo * 60)
            return e
        }
        return [
            entry(1, "Connected to Home: DNS set to 1.1.1.1, 1.0.0.1"),
            entry(26, "Wi-Fi disconnected: DNS restored to network default"),
            entry(184, "Connected to Office: DNS set to 10.0.0.53"),
        ]
    }
}

/// `DNSwitch --screenshots <dir>` renders the settings window in light and
/// dark mode to PNGs (with demo data), then quits. Used by Scripts/screenshots.sh.
enum Screenshots {
    static var outputDirectory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--screenshots"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
    }

    @MainActor
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let size = NSSize(width: 640, height: 820)
        for (name, appearance) in [("settings-light", NSAppearance.Name.aqua), ("settings-dark", .darkAqua)] {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "DNSwitch"
            window.appearance = NSAppearance(named: appearance)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView:
                SettingsView().environmentObject(AppState.shared).frame(width: size.width, height: size.height))
            // Key + active so controls draw with the accent color, as in real use.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            // Park it off-screen: it stays key (so controls draw active)
            // without flashing on the user's display.
            window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            window.makeFirstResponder(nil)  // no focus ring on the first field
            RunLoop.main.run(until: Date().addingTimeInterval(1.5))

            // Render the whole frame view so the title bar is included.
            guard let frameView = window.contentView?.superview,
                  let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { continue }
            frameView.cacheDisplay(in: frameView.bounds, to: rep)
            let framed = addWindowFrame(rep, dark: appearance == .darkAqua)
            try? framed.write(to: dir.appendingPathComponent("\(name).png"))
            window.close()
        }
        NSApp.terminate(nil)
    }

    /// Rounded corners, hairline border and soft shadow on a transparent canvas.
    private static func addWindowFrame(_ rep: NSBitmapImageRep, dark: Bool) -> Data {
        let scale = CGFloat(rep.pixelsWide) / rep.size.width
        let margin: CGFloat = 40, radius: CGFloat = 12
        let canvas = NSSize(width: rep.size.width + margin * 2, height: rep.size.height + margin * 2)
        let out = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(canvas.width * scale), pixelsHigh: Int(canvas.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        out.size = canvas
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        let rect = NSRect(x: margin, y: margin, width: rep.size.width, height: rep.size.height)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        NSGraphicsContext.current?.saveGraphicsState()
        shadow.set()
        NSColor.windowBackgroundColor.setFill()
        path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        rep.draw(in: rect)
        NSGraphicsContext.current?.restoreGraphicsState()

        (dark ? NSColor.white.withAlphaComponent(0.18) : NSColor.black.withAlphaComponent(0.15)).setStroke()
        path.lineWidth = 1
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
        return out.representation(using: .png, properties: [:])!
    }
}
