import Foundation
import CoreGraphics
import OrbitCore

final class PreferencesTests {
    func testDefaultsPreserveOneSecondAndExistingSize() {
        let p = LauncherPreferences()
        XCTAssertEqual(p.effectiveHoldDuration, 1)
        XCTAssertEqual(p.effectiveDialScale, 1)
    }
    func testPreferencesRoundTripAndMissingKeysUseDefaults() {
        var p = LauncherPreferences(); p.holdDuration = 2.4; p.dialScale = 1.35
        let decoded = try? JSONDecoder().decode(LauncherPreferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded, p)
        let legacy = try? JSONDecoder().decode(LauncherPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(legacy, LauncherPreferences())
    }
    func testInvalidPreferencesCannotBreakTimerOrGeometry() {
        var p = LauncherPreferences(); p.holdDuration = -1; p.dialScale = 999
        XCTAssertEqual(p.effectiveHoldDuration, 0.3)
        XCTAssertEqual(p.effectiveDialScale, 1.5)
        p.holdDuration = .nan; p.dialScale = .infinity
        XCTAssertEqual(p.effectiveHoldDuration, 1)
        XCTAssertEqual(p.effectiveDialScale, 1)
    }
    func testShorterAndLongerDurationsAreRespected() {
        var short = Gesture(); _ = short.down(at: .zero, time: 10, holdDuration: 0.5)
        XCTAssertEqual(short.tick(time: 10.49), .swallow)
        XCTAssertEqual(short.tick(time: 10.5), .show)
        var long = Gesture(); _ = long.down(at: .zero, time: 10, holdDuration: 2)
        XCTAssertEqual(long.tick(time: 11), .swallow)
        XCTAssertEqual(long.tick(time: 12), .show)
    }
    func testScaledDialHitRegionsAndCentersMatchPaintedSize() {
        for scale in [0.75, 1.0, 1.5] {
            XCTAssertEqual(DialGeometry.selection(at: CGPoint(x: 0, y: 123 * scale), center: .zero, count: 6, scale: scale), 0)
            XCTAssertNil(DialGeometry.selection(at: CGPoint(x: 0, y: 57 * scale), center: .zero, count: 6, scale: scale))
            XCTAssertNil(DialGeometry.selection(at: CGPoint(x: 0, y: 185 * scale), center: .zero, count: 6, scale: scale))
            let clamped = DialGeometry.center(near: .zero, in: CGRect(x: 0, y: 0, width: 1440, height: 900), margin: 202 * scale)
            XCTAssertEqual(clamped, CGPoint(x: 202 * scale, y: 202 * scale))
        }
    }
}
