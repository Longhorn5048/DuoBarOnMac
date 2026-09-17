import XCTest
import AppKit
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

    func testWiFiColorPreferenceInvalidatesGlyphImage() {
        let suiteName = "DuoBarOnMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = PresentationState(preferences: AppPreferences(defaults: defaults))
        XCTAssertTrue(model.wifiColorEnabled)
        model.wifi = WiFiState(status: .connected, rssi: -50)
        let renderer = GlyphImageRenderer()

        let colored = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        XCTAssertTrue(hasGreenSignalPixel(in: colored))
        model.wifiColorEnabled = false
        let monochrome = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        XCTAssertFalse(colored === monochrome)
        XCTAssertFalse(hasGreenSignalPixel(in: monochrome))

        model.wifi.rssi = -52
        let sameStrength = renderer.image(snapshot: model.glyphSnapshot, displaySize: 22, scale: 2, dark: false)
        XCTAssertTrue(monochrome === sameStrength)
    }

    func testWiFiDotCountInvalidatesImageAndSameStrengthStillHitsCache() {
        let suiteName = "DuoBarOnMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = PresentationState(preferences: AppPreferences(defaults: defaults))
        model.wifi = WiFiState(status: .connected, rssi: -50)
        let renderer = GlyphImageRenderer()
        let fourDots = renderer.image(snapshot: model.glyphSnapshot, displaySize: 24, scale: 2, dark: false)

        model.wifiDotCount = .three
        let threeDots = renderer.image(snapshot: model.glyphSnapshot, displaySize: 24, scale: 2, dark: false)
        XCTAssertFalse(fourDots === threeDots)

        model.wifi.rssi = -54
        let sameThreeDotTier = renderer.image(snapshot: model.glyphSnapshot, displaySize: 24, scale: 2, dark: false)
        XCTAssertTrue(threeDots === sameThreeDotTier)
    }

    func testAllSixteenPointAndColorPreferenceCombinationsRender() {
        let suiteName = "DuoBarOnMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = PresentationState(preferences: AppPreferences(defaults: defaults))
        model.wifi = WiFiState(status: .connected, rssi: -50)
        model.battery = BatteryState(availability: .available, percent: 5, powerStatus: .charging)
        model.isLowPowerModeEnabled = true
        let renderer = GlyphImageRenderer()

        for dotCount in WiFiDotCount.allCases {
            for chargingColor in [false, true] {
                for batteryColor in [false, true] {
                    for wifiColor in [false, true] {
                        model.wifiDotCount = dotCount
                        model.chargingColorEnabled = chargingColor
                        model.batteryColorEnabled = batteryColor
                        model.wifiColorEnabled = wifiColor

                        let snapshot = model.glyphSnapshot
                        let image = renderer.image(snapshot: snapshot, displaySize: 24, scale: 2, dark: false)
                        XCTAssertGreaterThan(image.size.width, 0)
                        XCTAssertEqual(snapshot.displayedWiFiStrength, dotCount == .three ? 3 : 4)
                    }
                }
            }
        }
    }

    private func hasGreenSignalPixel(in image: NSImage) -> Bool {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return false
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.greenComponent > 0.3,
                   color.greenComponent > color.redComponent * 1.3,
                   color.greenComponent > color.blueComponent * 1.2 {
                    return true
                }
            }
        }
        return false
    }
}
