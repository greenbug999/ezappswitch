import Foundation
import CoreGraphics
var failures = 0
var assertions = 0
func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: String = #file, line: Int = #line) {
    assertions += 1
    if actual != expected { failures += 1; print("FAIL \(URL(fileURLWithPath: file).lastPathComponent):\(line) expected \(expected), got \(actual)") }
}
func XCTAssertNil<T>(_ actual: T?, file: String = #file, line: Int = #line) {
    assertions += 1
    if actual != nil { failures += 1; print("FAIL \(URL(fileURLWithPath: file).lastPathComponent):\(line) expected nil") }
}
DialGeometryTests().testTopRightBottomLeftFollowClockwiseOrder()
DialGeometryTests().testCenterAndFarOutsideCancel()
DialGeometryTests().testAllAppCentersSelectTheirAppForEverySupportedCount()
DialGeometryTests().testClampDialToSecondaryScreenIncludingNegativeCoordinates()
DialGeometryTests().testSmallScreenStillReturnsValidCenter()
GestureTests().testQuickClickReplaysOriginalDownBeforeUp()
GestureTests().testOneSecondHoldConsumesClickAndChoosesOnRelease()
GestureTests().testDragCancelsBeforeActivationAndPreservesDownUpPair()
GestureTests().testEightPointJitterStillAllowsHold()
GestureTests().testMovingAwayThenReturningDoesNotReactivate()
GestureTests().testEscapeConsumesReleaseWithoutLaunching()
GestureTests().testInterruptReplaysPendingClickAndAllowsDragging()
GestureTests().testCancelPendingSwallowsOrphanRelease()
GestureTests().testReleaseQueuedBeforeTimerPreservesClick()
GestureTests().testPausingWhilePendingPreservesOriginalClick()
LauncherStateTests().testDefaultSixSlotsWithTwoEmptyPinsAndFourPlaceholders()
LauncherStateTests().testRecentUsesForegroundOrderAndMovesReusedAppToFront()
LauncherStateTests().testPinnedAppsNeverDuplicateInRecentSlotsAndBackfillWithNextRecent()
LauncherStateTests().testInsufficientHistoryKeepsEmptySlotsInTheirPositions()
LauncherStateTests().testCountCanChangeAndClampsToTwoThroughEight()
LauncherStateTests().testSameAppCannotOccupyBothPins()
LauncherStateTests().testPinChangeImmediatelyRefiltersRecentWithoutLosingHistory()
LauncherStateTests().testRoundTripPersistsPinsCountAndRecency()
LauncherStateTests().testHistoryBoundAndInvalidPinIndex()
PreferencesTests().testDefaultsPreserveOneSecondAndExistingSize()
PreferencesTests().testPreferencesRoundTripAndMissingKeysUseDefaults()
PreferencesTests().testInvalidPreferencesCannotBreakTimerOrGeometry()
PreferencesTests().testShorterAndLongerDurationsAreRespected()
PreferencesTests().testScaledDialHitRegionsAndCentersMatchPaintedSize()
print("\(assertions) assertions, \(failures) failures")
exit(failures == 0 ? 0 : 1)
