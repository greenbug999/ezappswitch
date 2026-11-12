import Foundation
import CoreGraphics
import OrbitCore

final class GestureTests {
    func testQuickClickReplaysOriginalDownBeforeUp() {
        var g = Gesture()
        XCTAssertEqual(g.down(at: .zero, time: 10), .swallow)
        XCTAssertEqual(g.tick(time: 10.999), .swallow)
        XCTAssertEqual(g.up(), .replayDownThenPass)
        XCTAssertEqual(g.state, .idle)
    }
    func testOneSecondHoldConsumesClickAndChoosesOnRelease() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 10)
        XCTAssertEqual(g.tick(time: 11), .show)
        XCTAssertEqual(g.move(to: CGPoint(x: 200, y: 100)), .swallow)
        XCTAssertEqual(g.up(), .select)
        XCTAssertEqual(g.state, .idle)
    }
    func testDragCancelsBeforeActivationAndPreservesDownUpPair() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 0)
        XCTAssertEqual(g.move(to: CGPoint(x: 9, y: 0)), .replayDownThenPass)
        XCTAssertEqual(g.tick(time: 2), .pass)
        XCTAssertEqual(g.move(to: CGPoint(x: 20, y: 10)), .pass)
        XCTAssertEqual(g.up(), .pass)
    }
    func testEightPointJitterStillAllowsHold() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 0)
        XCTAssertEqual(g.move(to: CGPoint(x: 8, y: 0)), .swallow)
        XCTAssertEqual(g.tick(time: 1), .show)
    }
    func testMovingAwayThenReturningDoesNotReactivate() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 0)
        _ = g.move(to: CGPoint(x: 10, y: 0))
        _ = g.move(to: .zero)
        XCTAssertEqual(g.tick(time: 1), .pass)
    }
    func testEscapeConsumesReleaseWithoutLaunching() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 0)
        _ = g.tick(time: 1)
        XCTAssertEqual(g.cancel(), .cancel)
        XCTAssertEqual(g.up(), .swallow)
        XCTAssertEqual(g.state, .idle)
    }
    func testInterruptReplaysPendingClickAndAllowsDragging() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 0)
        XCTAssertEqual(g.interrupt(), .replayDownThenPass)
        XCTAssertEqual(g.up(), .pass)
    }
    func testCancelPendingSwallowsOrphanRelease() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 0)
        _ = g.cancel()
        XCTAssertEqual(g.up(), .swallow)
    }
    func testReleaseQueuedBeforeTimerPreservesClick() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 0)
        XCTAssertEqual(g.tick(time: 1.1, buttonDown: false), .swallow)
        XCTAssertEqual(g.state, .pending)
        XCTAssertEqual(g.up(), .replayDownThenPass)
    }
    func testPausingWhilePendingPreservesOriginalClick() {
        var g = Gesture()
        _ = g.down(at: .zero, time: 0)
        XCTAssertEqual(g.tick(time: 1.1, enabled: false), .swallow)
        XCTAssertEqual(g.up(), .replayDownThenPass)
    }
}
