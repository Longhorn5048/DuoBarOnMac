import XCTest
import IOKit.ps
@testable import DuoBarOnMac

final class PresentationStateTests: XCTestCase {
    func testRSSIMapsToFourMonotonicStrengthLevels() {
        let values = [-1, -55, -56, -65, -66, -75, -76]
        let strengths = values.map { WiFiState(status: .connected, rssi: $0).strength }
        XCTAssertEqual(strengths, [4, 4, 3, 3, 2, 2, 1])
        XCTAssertNil(WiFiState(status: .connected, rssi: 0).strength)
    }

    func testZeroBatteryDoesNotProduceRingProgress() {
        let state = BatteryState(availability: .available, percent: 0, powerStatus: .onBattery)
        XCTAssertEqual(state.fraction, 0)
    }

    func testDefaultCenterModeIsWiFi() {
        let suiteName = "DuoBarOnMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.centerMode, .wifi)
    }

    @MainActor
    func testWiFiColorDefaultsOnAndPersists() {
        let suiteName = "DuoBarOnMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = PresentationState(preferences: AppPreferences(defaults: defaults))
        XCTAssertTrue(model.wifiColorEnabled)
        XCTAssertEqual(model.wifiDotCount, .four)
        XCTAssertTrue(model.chargingColorEnabled)
        XCTAssertTrue(model.batteryColorEnabled)

        model.wifiColorEnabled = false
        model.wifiDotCount = .three
        model.chargingColorEnabled = false
        model.batteryColorEnabled = false
        let restored = PresentationState(preferences: AppPreferences(defaults: defaults))
        XCTAssertFalse(restored.wifiColorEnabled)
        XCTAssertEqual(restored.wifiDotCount, .three)
        XCTAssertFalse(restored.chargingColorEnabled)
        XCTAssertFalse(restored.batteryColorEnabled)
    }

    func testInvalidWiFiDotCountFallsBackToFour() {
        let suiteName = "DuoBarOnMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(5, forKey: "wifiDotCount")

        XCTAssertEqual(AppPreferences(defaults: defaults).wifiDotCount, .four)
    }

    func testThreeAndFourDotStrengthMappingsKeepFourLevelSource() {
        let rawStrengths = [4, 3, 2, 1]
        XCTAssertEqual(rawStrengths.map { WiFiDotCount.four.displayedStrength(for: $0) }, [4, 3, 2, 1])
        XCTAssertEqual(rawStrengths.map { WiFiDotCount.three.displayedStrength(for: $0) }, [3, 3, 2, 1])
        XCTAssertNil(WiFiDotCount.three.displayedStrength(for: nil))
        XCTAssertNil(WiFiDotCount.three.displayedStrength(for: 0))
        XCTAssertEqual(WiFiDotCount.three.colorTier(for: 3), 4)
        XCTAssertEqual(WiFiDotCount.four.colorTier(for: 3), 3)
    }

    @MainActor
    func testIncompletePowerDescriptionRemainsUnknown() {
        let state = PowerProvider.state(from: [
            kIOPSPowerSourceStateKey: kIOPSACPowerValue
        ])

        XCTAssertNil(state.percent)
        XCTAssertEqual(state.powerStatus, .unknown)
    }

    @MainActor
    func testPowerDescriptionWithMissingChargingFlagDoesNotAssumeCharging() {
        let state = PowerProvider.state(from: [
            kIOPSCurrentCapacityKey: 80,
            kIOPSMaxCapacityKey: 100,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue
        ])

        XCTAssertEqual(state.percent, 80)
        XCTAssertEqual(state.powerStatus, .unknown)
    }
}

@MainActor
final class TransientEventCoordinatorTests: XCTestCase {
    func testUnknownInitialSnapshotDoesNotEmitEvent() {
        let model = PresentationState(preferences: AppPreferences(defaults: UserDefaults(suiteName: suiteName())!))
        let coordinator = TransientEventCoordinator(model: model)

        coordinator.handleBatteryChange(
            from: BatteryState(),
            to: BatteryState(availability: .available, percent: 50, powerStatus: .charging),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertNil(model.transientPresentation)
    }

    func testHigherPriorityEventPreemptsLowerPriorityEvent() {
        let model = PresentationState(preferences: AppPreferences(defaults: UserDefaults(suiteName: suiteName())!))
        let coordinator = TransientEventCoordinator(model: model)
        let now = Date(timeIntervalSince1970: 200)

        coordinator.ingest(kind: .wifiConnected, sourceKey: "wifi:test", now: now)
        coordinator.ingest(kind: .chargingStarted, sourceKey: "power:test", now: now.addingTimeInterval(0.1))

        XCTAssertEqual(model.transientPresentation?.kind, .chargingStarted)
    }

    func testDuplicateSourceWithinTwoSecondsIsDropped() {
        let model = PresentationState(preferences: AppPreferences(defaults: UserDefaults(suiteName: suiteName())!))
        let coordinator = TransientEventCoordinator(model: model)
        let now = Date(timeIntervalSince1970: 400)

        coordinator.ingest(kind: .wifiConnected, sourceKey: "wifi:test", now: now)
        coordinator.ingest(kind: .wifiConnected, sourceKey: "wifi:test", now: now.addingTimeInterval(1.5))

        XCTAssertEqual(coordinator.pendingEventCountForTesting, 0)
        XCTAssertEqual(coordinator.activeEventKindForTesting, .wifiConnected)
    }

    func testExpiredActiveAndPendingEventsAreDiscardedBeforeNextPlayback() {
        let model = PresentationState(preferences: AppPreferences(defaults: UserDefaults(suiteName: suiteName())!))
        let coordinator = TransientEventCoordinator(model: model)
        let now = Date(timeIntervalSince1970: 500)

        coordinator.ingest(kind: .chargingStarted, sourceKey: "power:charging", now: now)
        coordinator.ingest(kind: .wifiConnected, sourceKey: "wifi:connected", now: now.addingTimeInterval(0.1))
        XCTAssertEqual(coordinator.pendingEventCountForTesting, 1)

        coordinator.ingest(kind: .wifiDisconnected, sourceKey: "wifi:disconnected", now: now.addingTimeInterval(6))

        XCTAssertEqual(coordinator.pendingEventCountForTesting, 0)
        XCTAssertEqual(coordinator.activeEventKindForTesting, .wifiDisconnected)
    }

    func testModeSwitchCancelsActiveAndPendingEvents() {
        let model = PresentationState(preferences: AppPreferences(defaults: UserDefaults(suiteName: suiteName())!))
        let coordinator = TransientEventCoordinator(model: model)
        let now = Date(timeIntervalSince1970: 300)

        coordinator.ingest(kind: .chargingStarted, sourceKey: "power:test", now: now)
        coordinator.ingest(kind: .wifiConnected, sourceKey: "wifi:test", now: now.addingTimeInterval(0.1))
        coordinator.cancelForModeSwitch()

        XCTAssertNil(model.transientPresentation)
    }

    func testBluetoothQuickReconnectIsFoldedBeforePlayback() {
        let model = PresentationState(preferences: AppPreferences(defaults: UserDefaults(suiteName: suiteName())!))
        let coordinator = TransientEventCoordinator(model: model)
        let old = BluetoothState(availability: .available)
        let connected = BluetoothState(
            availability: .available,
            connectedDevices: [BluetoothDeviceState(id: "a", name: "耳机")]
        )
        let now = Date(timeIntervalSince1970: 600)

        coordinator.handleBluetoothChange(from: old, to: connected, now: now)
        coordinator.handleBluetoothChange(from: connected, to: old, now: now.addingTimeInterval(0.2))
        coordinator.flushPendingBluetoothForTesting(now: now.addingTimeInterval(0.5))

        XCTAssertNil(model.transientPresentation)
    }

    private func suiteName() -> String {
        "DuoBarOnMacTests.\(UUID().uuidString)"
    }
}
