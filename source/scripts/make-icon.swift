import AppKit
import Foundation

let folder = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for side in [16, 32, 64, 128, 256, 512, 1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let t = NSAffineTransform(); t.scale(by: CGFloat(side) / 1024); t.concat()
    NSColor(calibratedRed: 0.075, green: 0.105, blue: 0.17, alpha: 1).setFill()
    NSBezierPath(roundedRect: CGRect(x: 62, y: 62, width: 900, height: 900), xRadius: 202, yRadius: 202).fill()
    NSColor(calibratedRed: 0.21, green: 0.33, blue: 0.52, alpha: 1).setStroke()
    let orbit = NSBezierPath(ovalIn: CGRect(x: 228, y: 228, width: 568, height: 568)); orbit.lineWidth = 5; orbit.stroke()
    for index in 0..<6 {
        let angle = Double(index) * Double.pi / 3
        let x = 512 + sin(angle) * 284, y = 512 + cos(angle) * 284
        (index == 1 ? NSColor(calibratedRed: 0.30, green: 0.64, blue: 1, alpha: 1) : NSColor(calibratedRed: 0.79, green: 0.85, blue: 0.94, alpha: 1)).setFill()
        NSBezierPath(roundedRect: CGRect(x: x - 63, y: y - 63, width: 126, height: 126), xRadius: 35, yRadius: 35).fill()
    }
    NSColor.white.setFill(); NSBezierPath(ovalIn: CGRect(x: 472, y: 472, width: 80, height: 80)).fill()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("icon render") }
    try png.write(to: URL(fileURLWithPath: "\(folder)/\(side).png"))
}
