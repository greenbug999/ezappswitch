import Foundation
import CoreGraphics

public struct Gesture {
    public enum State: Equatable { case idle, pending, dragging, choosing, consumed }
    public enum Effect: Equatable { case pass, swallow, replayDownThenPass, show, select, cancel }
    public private(set) var state: State = .idle
    private var origin = CGPoint.zero
    private var start: Double = 0
    private var duration: Double = 1
    public init() {}
    public mutating func down(at point: CGPoint, time: Double, holdDuration: Double = 1) -> Effect {
        origin = point; start = time; state = .pending
        duration = holdDuration.isFinite ? max(0.3, min(5, holdDuration)) : 1
        return .swallow
    }
    public mutating func move(to point: CGPoint) -> Effect {
        switch state {
        case .pending:
            if hypot(point.x - origin.x, point.y - origin.y) > 8 {
                state = .dragging
                return .replayDownThenPass
            }
            return .swallow
        case .choosing, .consumed: return .swallow
        default: return .pass
        }
    }
    public mutating func tick(time: Double, buttonDown: Bool = true, enabled: Bool = true) -> Effect {
        guard state == .pending else { return .pass }
        guard buttonDown, enabled else { return .swallow }
        guard time - start >= duration else { return .swallow }
        state = .choosing
        return .show
    }
    public mutating func up() -> Effect {
        defer { state = .idle }
        switch state {
        case .pending: return .replayDownThenPass
        case .choosing: return .select
        case .consumed: return .swallow
        default: return .pass
        }
    }
    public mutating func interrupt() -> Effect {
        if state == .pending { state = .dragging; return .replayDownThenPass }
        if state == .choosing { state = .consumed; return .cancel }
        return .pass
    }
    public mutating func cancel() -> Effect {
        guard state == .pending || state == .choosing else { return .pass }
        state = .consumed
        return .cancel
    }
}
