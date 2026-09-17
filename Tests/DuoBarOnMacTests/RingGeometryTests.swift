import XCTest
import SwiftUI
@testable import DuoBarOnMac

final class RingGeometryTests: XCTestCase {
    func testRingSweepStaysLinearAcrossCalibrationValues() {
        let cases: [(Double, Double)] = [
            (0, 0),
            (0.01, 2.7),
            (0.05, 13.5),
            (0.10, 27),
            (0.20, 54),
            (0.25, 67.5),
            (0.40, 108),
            (0.50, 135),
            (0.75, 202.5),
            (0.99, 267.3),
            (1, 270)
        ]

        for (progress, expectedSweep) in cases {
            XCTAssertEqual(BatteryRingGeometry.sweepDegrees(for: progress), expectedSweep, accuracy: 0.0001)
        }
    }

    func testZeroHasNoBrightPathAndInvalidProgressClampsSafely() {
        let rect = CGRect(x: 0, y: 0, width: 24, height: 24)
        XCTAssertTrue(RingShape(progress: 0).path(in: rect).isEmpty)
        XCTAssertTrue(RingShape(progress: .nan).path(in: rect).isEmpty)
        XCTAssertEqual(BatteryRingGeometry.sweepDegrees(for: -0.5), 0)
        XCTAssertEqual(BatteryRingGeometry.sweepDegrees(for: 1.5), 270)
    }

    func testTwentyPercentPathStaysOnExpectedSideAndFortyIsTwiceTheSweep() {
        let rect = CGRect(x: 0, y: 0, width: 24, height: 24)
        let twenty = RingShape(progress: 0.20).path(in: rect).boundingRect
        let forty = RingShape(progress: 0.40).path(in: rect).boundingRect

        XCTAssertLessThan(twenty.maxX, rect.midX)
        XCTAssertGreaterThan(twenty.minY, 0)
        XCTAssertGreaterThan(twenty.maxY, rect.midY)
        XCTAssertEqual(
            BatteryRingGeometry.sweepDegrees(for: 0.40),
            BatteryRingGeometry.sweepDegrees(for: 0.20) * 2,
            accuracy: 0.0001
        )
        XCTAssertGreaterThan(forty.height, twenty.height)
    }

    func testHalfAndFullChargeCoverHalfAndAllOfTheOpenTrack() {
        let rect = CGRect(x: 0, y: 0, width: 24, height: 24)
        let half = RingShape(progress: 0.5).path(in: rect).boundingRect
        let full = RingShape(progress: 1).path(in: rect).boundingRect

        XCTAssertEqual(BatteryRingGeometry.sweepDegrees(for: 0.5), 135, accuracy: 0.0001)
        XCTAssertEqual(BatteryRingGeometry.sweepDegrees(for: 1), 270, accuracy: 0.0001)
        XCTAssertLessThan(half.minX, rect.midX)
        XCTAssertLessThan(half.minY, rect.midY)
        XCTAssertLessThan(full.minX, rect.midX)
        XCTAssertGreaterThan(full.maxX, rect.midX)
        XCTAssertLessThan(full.maxY, rect.maxY)
    }
}
