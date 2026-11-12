import Foundation
import CoreGraphics
import OrbitCore

final class DialGeometryTests {
    func testTopRightBottomLeftFollowClockwiseOrder() {
        XCTAssertEqual(DialGeometry.selection(at: CGPoint(x: 0, y: 130), center: .zero, count: 8), 0)
        XCTAssertEqual(DialGeometry.selection(at: CGPoint(x: 130, y: 0), center: .zero, count: 8), 2)
        XCTAssertEqual(DialGeometry.selection(at: CGPoint(x: 0, y: -130), center: .zero, count: 8), 4)
        XCTAssertEqual(DialGeometry.selection(at: CGPoint(x: -130, y: 0), center: .zero, count: 8), 6)
    }
    func testCenterAndFarOutsideCancel() {
        XCTAssertNil(DialGeometry.selection(at: .zero, center: .zero, count: 8))
        XCTAssertNil(DialGeometry.selection(at: CGPoint(x: 40, y: 0), center: .zero, count: 8))
        XCTAssertNil(DialGeometry.selection(at: CGPoint(x: 260, y: 0), center: .zero, count: 8))
        XCTAssertNil(DialGeometry.selection(at: CGPoint(x: 185, y: 0), center: .zero, count: 8))
        XCTAssertNil(DialGeometry.selection(at: CGPoint(x: 100, y: 0), center: .zero, count: 0))
    }
    func testAllAppCentersSelectTheirAppForEverySupportedCount() {
        for count in 1...12 {
            for index in 0..<count {
                let p = DialGeometry.position(index: index, count: count, radius: 125)
                XCTAssertEqual(DialGeometry.selection(at: p, center: .zero, count: count), index)
            }
        }
    }
    func testClampDialToSecondaryScreenIncludingNegativeCoordinates() {
        let rect = CGRect(x: -1440, y: 100, width: 1440, height: 900)
        XCTAssertEqual(DialGeometry.center(near: CGPoint(x: -1430, y: 990), in: rect), CGPoint(x: -1238, y: 798))
    }
    func testSmallScreenStillReturnsValidCenter() {
        XCTAssertEqual(DialGeometry.center(near: .zero, in: CGRect(x: 0, y: 0, width: 300, height: 300)), CGPoint(x: 150, y: 150))
    }
}
