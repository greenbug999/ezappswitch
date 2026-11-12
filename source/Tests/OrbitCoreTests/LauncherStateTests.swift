import Foundation
import OrbitCore

final class LauncherStateTests {
    func app(_ name: String) -> AppRecord { AppRecord(id: name, name: name, path: "/Applications/\(name).app") }
    func testDefaultSixSlotsWithTwoEmptyPinsAndFourPlaceholders() {
        let state = LauncherState()
        XCTAssertEqual(state.slots.count, 6)
        XCTAssertEqual(state.slots.compactMap { $0 }.count, 0)
    }
    func testRecentUsesForegroundOrderAndMovesReusedAppToFront() {
        var state = LauncherState()
        state.activate(app("A")); state.activate(app("B")); state.activate(app("A"))
        XCTAssertEqual(state.recent.map(\.id), ["A", "B"])
        XCTAssertEqual(state.slots.dropFirst(2).compactMap { $0?.id }, ["A", "B"])
    }
    func testPinnedAppsNeverDuplicateInRecentSlotsAndBackfillWithNextRecent() {
        var state = LauncherState()
        state.pin(app("A"), at: 0); state.pin(app("B"), at: 1)
        for name in ["G", "F", "E", "D", "C", "B", "A"] { state.activate(app(name)) }
        XCTAssertEqual(state.slots.compactMap { $0?.id }, ["A", "B", "C", "D", "E", "F"])
    }
    func testInsufficientHistoryKeepsEmptySlotsInTheirPositions() {
        var state = LauncherState()
        state.pin(app("A"), at: 1); state.activate(app("B"))
        XCTAssertEqual(state.slots.map { $0?.id }, [nil, "A", "B", nil, nil, nil])
    }
    func testCountCanChangeAndClampsToTwoThroughEight() {
        var state = LauncherState()
        state.slotCount = 8
        XCTAssertEqual(state.slots.count, 8)
        state.slotCount = 2
        XCTAssertEqual(state.slots.count, 2)
        state.slotCount = 999
        XCTAssertEqual(state.slots.count, 8)
        state.slotCount = 0
        XCTAssertEqual(state.slots.count, 2)
    }
    func testSameAppCannotOccupyBothPins() {
        var state = LauncherState()
        state.pin(app("A"), at: 0); state.pin(app("A"), at: 1)
        XCTAssertEqual(state.slots.prefix(2).map { $0?.id }, [nil, "A"])
    }
    func testPinChangeImmediatelyRefiltersRecentWithoutLosingHistory() {
        var state = LauncherState()
        state.activate(app("A")); state.activate(app("B")); state.pin(app("B"), at: 0)
        XCTAssertEqual(state.slots.map { $0?.id }, ["B", nil, "A", nil, nil, nil])
        state.pin(nil, at: 0)
        XCTAssertEqual(state.slots.map { $0?.id }, [nil, nil, "B", "A", nil, nil])
    }
    func testRoundTripPersistsPinsCountAndRecency() {
        var state = LauncherState()
        state.slotCount = 8; state.pin(app("A"), at: 0); state.activate(app("B"))
        let decoded = try? JSONDecoder().decode(LauncherState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }
    func testHistoryBoundAndInvalidPinIndex() {
        var state = LauncherState()
        for index in 0..<100 { state.activate(app("\(index)")) }
        XCTAssertEqual(state.recent.count, 50)
        state.pin(app("A"), at: 8)
        XCTAssertEqual(state.pinned.count, 2)
    }
}
