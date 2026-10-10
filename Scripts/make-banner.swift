// Renders the README banner (also sized for GitHub's social preview).
// Usage: swift Scripts/make-banner.swift <icon.png> <output.jpg>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let icon = NSImage(contentsOfFile: args[1]) else {
    print("usage: make-banner.swift <icon.png> <output.jpg>")
    exit(1)
}
let output = URL(fileURLWithPath: args[2])

let size = NSSize(width: 1280, height: 640)
let scale: CGFloat = 2

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: descriptor, size: size) ?? base
}

func glow(center: NSPoint, radius: CGFloat, _ c: NSColor) {
    NSGradient(colors: [c, c.withAlphaComponent(0)])!
        .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
}

func draw() {
    let bounds = NSRect(origin: .zero, size: size)

    // Deep night background with soft color glows.
    NSGradient(colors: [color(0x0B1026), color(0x111A3D), color(0x1A1446)])!.draw(in: bounds, angle: -35)
    glow(center: NSPoint(x: 260, y: 600), radius: 520, color(0x22D3EE, 0.30))
    glow(center: NSPoint(x: 1120, y: 40), radius: 560, color(0x6366F1, 0.38))
    glow(center: NSPoint(x: 760, y: 700), radius: 380, color(0x3B82F6, 0.22))

    // Faint dot grid.
    color(0xFFFFFF, 0.05).setFill()
    stride(from: CGFloat(20), to: size.width, by: 32).forEach { x in
        stride(from: CGFloat(20), to: size.height, by: 32).forEach { y in
            NSBezierPath(ovalIn: NSRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)).fill()
        }
    }

    // App mark.
    let iconRect = NSRect(x: 96, y: 150, width: 340, height: 340)
    icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)

    // Wordmark + tagline.
    let textX: CGFloat = 476
    NSAttributedString(string: "Snaps", attributes: [
        .font: rounded(150, .bold),
        .foregroundColor: NSColor.white,
        .kern: -3,
    ]).draw(at: NSPoint(x: textX - 6, y: 306))

    NSAttributedString(string: "Screenshots that land on your clipboard.", attributes: [
        .font: rounded(34, .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.72),
    ]).draw(at: NSPoint(x: textX, y: 250))

    // Glass shortcut chips.
    let chips = [("⌃⇧4", "Area"), ("⌃⇧5", "Window"), ("⌃⇧3", "Screen"), ("⌃⇧G", "Gallery")]
    var x = textX
    for (keys, label) in chips {
        let keyText = NSAttributedString(string: keys, attributes: [
            .font: rounded(22, .bold),
            .foregroundColor: NSColor.white,
        ])
        let labelText = NSAttributedString(string: label, attributes: [
            .font: rounded(22, .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
        ])
        let width = keyText.size().width + labelText.size().width + 46
        let chip = NSRect(x: x, y: 158, width: width, height: 52)
        let path = NSBezierPath(roundedRect: chip, xRadius: 26, yRadius: 26)
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.16), NSColor.white.withAlphaComponent(0.06)])!
            .draw(in: path, angle: -90)
        NSColor.white.withAlphaComponent(0.22).setStroke()
        path.lineWidth = 1.5
        path.stroke()

        keyText.draw(at: NSPoint(x: chip.minX + 18, y: chip.midY - keyText.size().height / 2))
        labelText.draw(at: NSPoint(x: chip.minX + 28 + keyText.size().width, y: chip.midY - labelText.size().height / 2))
        x += width + 12
    }

    // macOS badge.
    NSAttributedString(string: "Native macOS  ·  Liquid Glass", attributes: [
        .font: rounded(18, .semibold),
        .foregroundColor: color(0x67E8F9, 0.85),
        .kern: 1.5,
    ]).draw(at: NSPoint(x: textX, y: 474))
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width * scale),
    pixelsHigh: Int(size.height * scale),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
draw()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: output)
print("Wrote \(output.path)")
