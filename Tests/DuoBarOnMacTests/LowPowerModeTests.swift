import XCTest
@testable import DuoBarOnMac

final class LowPowerModeTests: XCTestCase {
    func testReadsEachPowerProfileIndependently() {
        let settings = PowerModeSettings(output: """
        Battery Power:
         lowpowermode 1
         sleep 5
        AC Power:
         lowpowermode 0
        """)
        XCTAssertEqual(settings[.battery], true)
        XCTAssertEqual(settings[.adapter], false)
    }

    func testMissingOrInvalidValuesRemainUnknown() {
        let settings = PowerModeSettings(output: """
        Battery Power:
         lowpowermode unknown
        UPS Power:
         lowpowermode 1
        AC Power:
         sleep 0
        """)
        XCTAssertNil(settings[.battery])
        XCTAssertNil(settings[.adapter])
    }

}
