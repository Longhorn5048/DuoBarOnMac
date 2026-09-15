import XCTest
@testable import DuoBarOnMac

@MainActor
final class GlyphRenderingTests: XCTestCase {
    func testSignalChangesWithinSameBarReuseImageButCrossingThresholdRenders() {
        let model = PresentationState()
        let renderer = GlyphImageRenderer()
        model.wifi = WiFiState(status: .connected, rssi: -51)
        let first = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        model.wifi.rssi = -54
        let sameBars = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        XCTAssertTrue(first === sameBars)
        model.wifi.rssi = -60
        let fewerBars = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        XCTAssertFalse(first === fewerBars)
    }

    func testDetailsOnlyBatteryChangeDoesNotRenderMenuImageAgain() {
        let model = PresentationState()
        let renderer = GlyphImageRenderer()
        model.battery = BatteryState(availability: .available, percent: 80, powerStatus: .charging, minutesToFull: 25)
        let first = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        model.battery.minutesToFull = 24
        let second = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        XCTAssertTrue(first === second)
        model.battery.powerStatus = .connectedPaused
        let paused = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        XCTAssertFalse(first === paused)
    }

    func testAppearanceChangeInvalidatesImageCache() {
        let renderer = GlyphImageRenderer()
        let snapshot = PresentationState().glyphSnapshot
        let light = renderer.image(snapshot: snapshot, displaySize: 22, scale: 2, dark: false)
        let dark = renderer.image(snapshot: snapshot, displaySize: 22, scale: 2, dark: true)
        XCTAssertFalse(light === dark)
    }
}
