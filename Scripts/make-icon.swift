// Renders the Snaps app icon to an .iconset directory.
// Usage: swift Scripts/make-icon.swift <output.iconset>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon() {
    // Apple's macOS icon grid: 824pt body inside a 1024pt canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x0284C7).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [color(0x5ED0FA), color(0x0EA5E9), color(0x0369A1), color(0x1E3A8A)])!
        .draw(in: squircle, angle: -90)

    // Soft glass sheen across the top.
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    let sheen = NSBezierPath(ovalIn: NSRect(x: -60, y: 560, width: 1144, height: 640))
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.34), NSColor.white.withAlphaComponent(0.0)])!
        .draw(in: sheen, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Inner glass pane.
    let pane = NSRect(x: 322, y: 352, width: 380, height: 320)
    let panePath = NSBezierPath(roundedRect: pane, xRadius: 46, yRadius: 46)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.42), NSColor.white.withAlphaComponent(0.14)])!
        .draw(in: panePath, angle: -90)
    NSColor.white.withAlphaComponent(0.7).setStroke()
    panePath.lineWidth = 6
    panePath.stroke()

    // Viewfinder brackets.
    let frame = NSRect(x: 232, y: 262, width: 560, height: 500)
    let arm: CGFloat = 132
    let radius: CGFloat = 54
    let brackets = NSBezierPath()
    brackets.lineWidth = 46
    brackets.lineCapStyle = .round
    brackets.lineJoinStyle = .round

    func corner(_ origin: NSPoint, _ dx: CGFloat, _ dy: CGFloat) {
        brackets.move(to: NSPoint(x: origin.x, y: origin.y + dy * arm))
        brackets.line(to: NSPoint(x: origin.x, y: origin.y + dy * radius))
        brackets.appendArc(
            from: origin,
            to: NSPoint(x: origin.x + dx * radius, y: origin.y),
            radius: radius
        )
        brackets.line(to: NSPoint(x: origin.x + dx * arm, y: origin.y))
    }
    corner(NSPoint(x: frame.minX, y: frame.maxY), 1, -1)
    corner(NSPoint(x: frame.maxX, y: frame.maxY), -1, -1)
    corner(NSPoint(x: frame.minX, y: frame.minY), 1, 1)
    corner(NSPoint(x: frame.maxX, y: frame.minY), -1, 1)

    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = color(0x0C4A6E, 0.45)
    glow.shadowBlurRadius = 18
    glow.shadowOffset = NSSize(width: 0, height: -6)
    glow.set()
    NSColor.white.setStroke()
    brackets.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // Subtle rim light.
    NSColor.white.withAlphaComponent(0.25).setStroke()
    let rim = NSBezierPath(roundedRect: body.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    rim.lineWidth = 4
    rim.stroke()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(pixels: base).write(to: output.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(pixels: base * 2).write(to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
print("Wrote \(output.path)")
