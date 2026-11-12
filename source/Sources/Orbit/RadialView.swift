import AppKit
import SwiftUI
import OrbitCore

final class RadialView: NSView {
    private let material = NSVisualEffectView()
    private let artwork = DialArtwork()
    var slots: [AppRecord?] { get { artwork.slots } set { artwork.slots = newValue } }
    var selection: Int? { get { artwork.selection } set { artwork.selection = newValue } }
    var icon: ((AppRecord) -> NSImage)? { get { artwork.icon } set { artwork.icon = newValue } }
    var preview = false { didSet { artwork.preview = preview; material.blendingMode = preview ? .withinWindow : .behindWindow } }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor; layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 12; layer?.shadowOffset = CGSize(width: 0, height: -5)
        material.material = .popover; material.blendingMode = .behindWindow; material.state = .active
        material.maskImage = NSImage(size: NSSize(width: 368, height: 368), flipped: false) { rect in
            NSColor.white.setFill(); NSBezierPath(ovalIn: rect).fill(); return true
        }
        addSubview(material); addSubview(artwork)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        let side = min(bounds.width, bounds.height)
        let canvas = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        material.frame = canvas.insetBy(dx: side * 18 / 404, dy: side * 18 / 404)
        artwork.frame = bounds
        layer?.shadowPath = CGPath(ellipseIn: material.frame, transform: nil)
    }
}

private final class DialArtwork: NSView {
    var slots: [AppRecord?] = Array(repeating: nil, count: 6) { didSet { needsDisplay = true } }
    var selection: Int? { didSet { needsDisplay = true } }
    var icon: ((AppRecord) -> NSImage)?
    var preview = false
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let scale = min(bounds.width, bounds.height) / 404
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: (bounds.width - 404 * scale) / 2, yBy: (bounds.height - 404 * scale) / 2)
        transform.scale(by: scale); transform.concat()
        let center = CGPoint(x: 202, y: 202)
        NSColor.labelColor.withAlphaComponent(0.035).setFill()
        NSBezierPath(ovalIn: CGRect(x: 151, y: 151, width: 102, height: 102)).fill()
        let step = 360.0 / Double(max(slots.count, 1))
        for index in slots.indices {
            let angle = 90 - Double(index) * step
            let wedge = NSBezierPath()
            wedge.appendArc(withCenter: center, radius: 177, startAngle: angle + step / 2 - 1, endAngle: angle - step / 2 + 1, clockwise: true)
            wedge.appendArc(withCenter: center, radius: 62, startAngle: angle - step / 2 + 1, endAngle: angle + step / 2 - 1, clockwise: false)
            wedge.close()
            if selection == index, slots[index] != nil {
                NSColor.controlAccentColor.withAlphaComponent(0.20).setFill(); wedge.fill()
            }
            let offset = DialGeometry.position(index: index, count: slots.count, radius: 123)
            let p = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
            if let item = slots[index] {
                let side: CGFloat = slots.count > 6 ? 40 : 46
                icon?(item).draw(in: CGRect(x: p.x - side / 2, y: p.y - 14, width: side, height: side), from: .zero, operation: .sourceOver, fraction: 1)
                text(item.name, rect: CGRect(x: p.x - 43, y: p.y - 36, width: 86, height: 18), size: 11, color: .labelColor, weight: .medium)
            } else {
                let ring = NSBezierPath(ovalIn: CGRect(x: p.x - 15, y: p.y - 6, width: 30, height: 30))
                NSColor.tertiaryLabelColor.setStroke(); ring.lineWidth = 1
                ring.setLineDash([3, 3], count: 2, phase: 0); ring.stroke()
                text(index < 2 ? "Not set" : "No recent", rect: CGRect(x: p.x - 43, y: p.y - 34, width: 86, height: 18), size: 11, color: .secondaryLabelColor)
            }
            if index < 2 {
                NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")?
                    .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor]))?
                    .draw(in: CGRect(x: p.x + 24, y: p.y + 23, width: 9, height: 9))
            }
        }
        let chosen = selection.flatMap { slots.indices.contains($0) ? slots[$0] : nil }
        text(chosen?.name ?? "ezappswitch", rect: CGRect(x: 151, y: 205, width: 102, height: 24), size: chosen == nil ? 15 : 13, color: .labelColor, weight: .semibold)
        text(chosen == nil ? (preview ? "Preview" : "Release to cancel") : "Release to open", rect: CGRect(x: 147, y: 181, width: 110, height: 20), size: 11, color: .secondaryLabelColor)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func text(_ value: String, rect: CGRect, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
        (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph])
    }
}

struct DialPreview: NSViewRepresentable {
    @ObservedObject var store: AppStore
    func makeNSView(context: Context) -> RadialView {
        let view = RadialView(); view.preview = true
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel("Radial menu preview. The first two clockwise slots are pinned; the rest are recent apps.")
        return view
    }
    func updateNSView(_ view: RadialView, context: Context) {
        view.icon = { store.icon($0) }; view.slots = store.slots
    }
}

final class DialPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    let dial = RadialView(frame: CGRect(x: 0, y: 0, width: 404, height: 404))
    var centerPoint = CGPoint.zero
    private(set) var dialScale: Double = 1
    init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 404, height: 404), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        level = .popUpMenu; ignoresMouseEvents = true; hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = dial; animationBehavior = .none
    }
    func show(at point: CGPoint, slots: [AppRecord?], scale: Double = 1, icon: @escaping (AppRecord) -> NSImage) {
        dialScale = scale.isFinite ? min(1.5, max(0.75, scale)) : 1
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        centerPoint = DialGeometry.center(near: point, in: screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1000, height: 800), margin: 202 * dialScale)
        dial.slots = slots; dial.icon = icon; dial.selection = nil
        let side = 404 * dialScale
        setFrame(CGRect(x: centerPoint.x - side / 2, y: centerPoint.y - side / 2, width: side, height: side), display: true)
        dial.frame = CGRect(x: 0, y: 0, width: side, height: side); dial.layoutSubtreeIfNeeded()
        orderFrontRegardless()
    }
    func update(at point: CGPoint) {
        dial.selection = DialGeometry.selection(at: point, center: centerPoint, count: dial.slots.count, scale: dialScale)
    }
    var selectedApp: AppRecord? {
        guard let index = dial.selection, dial.slots.indices.contains(index) else { return nil }
        return dial.slots[index]
    }
}
