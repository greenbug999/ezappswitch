import Foundation
import CoreGraphics

public enum DialGeometry {
    public static func selection(at point: CGPoint, center: CGPoint, count: Int, scale: Double = 1) -> Int? {
        guard count > 0, scale.isFinite, scale > 0 else { return nil }
        let dx = point.x - center.x, dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard distance >= 58 * scale, distance <= 184 * scale else { return nil }
        let angle = (atan2(dx, dy) + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
        return Int((angle / (.pi * 2 / Double(count))).rounded()) % count
    }
    public static func center(near pointer: CGPoint, in screen: CGRect, margin: Double = 202) -> CGPoint {
        func clamp(_ value: Double, low: Double, high: Double) -> Double {
            low > high ? (low + high) / 2 : min(max(value, low), high)
        }
        return CGPoint(x: clamp(pointer.x, low: screen.minX + margin, high: screen.maxX - margin),
                       y: clamp(pointer.y, low: screen.minY + margin, high: screen.maxY - margin))
    }
    public static func position(index: Int, count: Int, radius: Double) -> CGPoint {
        guard count > 0 else { return .zero }
        let angle = Double(index) * .pi * 2 / Double(count)
        return CGPoint(x: sin(angle) * radius, y: cos(angle) * radius)
    }
}
