import AppKit
let folder = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let n = size * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = AffineTransform(scale: CGFloat(n) / 512)
        (transform as NSAffineTransform).concat()
        NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 16, y: 16, width: 480, height: 480), xRadius: 108, yRadius: 108)
            .fill()
        NSColor(calibratedRed: 0.98, green: 0.70, blue: 0.25, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 222, y: 102, width: 58, height: 265), xRadius: 20, yRadius: 20)
            .fill()
        NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 128, y: 302, width: 250, height: 100), xRadius: 24, yRadius: 24)
            .fill()
        NSColor(calibratedRed: 0.24, green: 0.73, blue: 0.55, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 300, y: 72, width: 140, height: 140)).fill()
        NSColor.white.setStroke()
        let check = NSBezierPath()
        check.lineWidth = 15
        check.lineCapStyle = .round
        check.move(to: NSPoint(x: 334, y: 143))
        check.line(to: NSPoint(x: 359, y: 118))
        check.line(to: NSPoint(x: 406, y: 169))
        check.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(
            to: URL(fileURLWithPath: folder + "/icon_\(size)x\(size)\(suffix).png"))
    }
}
