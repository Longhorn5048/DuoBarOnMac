import XCTest
import IOKit.ps
@testable import DuoBarOnMac

@MainActor
final class ChargingGlyphTests: XCTestCase {
    private func snapshot(
        _ percent: Int?,
        _ power: PowerStatus,
        low: Bool = false,
        chargingColorEnabled: Bool = true,
        batteryColorEnabled: Bool = true
    ) -> GlyphSnapshot {
        GlyphSnapshot(batteryFraction: percent.map { Double($0) / 100 }, batteryPercent: percent,
                      powerStatus: power, batteryAvailability: .available,
                      wifiStatus: .connected, wifiStrength: 4, wifiColorEnabled: true,
                      wifiDotCount: .four, chargingColorEnabled: chargingColorEnabled,
                      batteryColorEnabled: batteryColorEnabled,
                      transitionProgress: 1, chargingPulseOpacity: 1,
                      transientPresentation: nil, isLowPowerModeEnabled: low)
    }

    func testColorPriorityAndTenPercentBoundary() {
        XCTAssertEqual(snapshot(5, .charging, low: true).ringTone, .charging)
        XCTAssertEqual(snapshot(9, .onBattery, low: true).ringTone, .critical)
        XCTAssertEqual(snapshot(10, .onBattery, low: true).ringTone, .lowPower)
        XCTAssertEqual(snapshot(10, .onBattery).ringTone, .normal)
        XCTAssertEqual(snapshot(nil, .onBattery).ringTone, .normal)
    }

    func testIndependentColorPreferencesPreserveRingPriority() {
        XCTAssertEqual(
            snapshot(5, .charging, low: true, chargingColorEnabled: false).ringTone,
            .critical
        )
        XCTAssertEqual(
            snapshot(5, .charging, low: true, chargingColorEnabled: false, batteryColorEnabled: false).ringTone,
            .normal
        )
        XCTAssertEqual(
            snapshot(80, .charging, chargingColorEnabled: false).ringTone,
            .normal
        )
        XCTAssertEqual(
            snapshot(80, .onBattery, low: true, batteryColorEnabled: false).ringTone,
            .normal
        )
    }

    func testChargingSymbolPersistsWithoutAnEventAndReleasesOnUnplug() {
        XCTAssertEqual(snapshot(80, .charging).powerSymbol, "bolt.fill")
        XCTAssertEqual(snapshot(80, .connectedPaused).powerSymbol, "pause.fill")
        XCTAssertNil(snapshot(80, .onBattery).powerSymbol)
    }

    func testTimeToFullIsNotTreatedAsPausedChargingSchedule() {
        XCTAssertNil(PowerProvider.chargeMinutes(120, status: .connectedPaused))
        XCTAssertNil(PowerProvider.chargeMinutes(-1, status: .charging))
        XCTAssertNil(PowerProvider.chargeMinutes(0, status: .charging))
        XCTAssertEqual(PowerProvider.chargeMinutes(120, status: .charging), 120)
    }

    func testSystemChargedFlagPreventsFalsePauseBelowOneHundred() {
        let state = PowerProvider.state(from: [
            kIOPSCurrentCapacityKey: 97, kIOPSMaxCapacityKey: 100,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSIsChargingKey: false, kIOPSIsChargedKey: true
        ])
        XCTAssertEqual(state.powerStatus, .charged)
        XCTAssertNil(state.minutesToFull)
    }
}
