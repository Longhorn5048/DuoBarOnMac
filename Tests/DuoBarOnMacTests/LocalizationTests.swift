import XCTest
@testable import DuoBarOnMac

final class LocalizationTests: XCTestCase {
    func testSupportedLocalesResolveFromTheModuleBundle() {
        let expected: [(String, String)] = [
            ("en", "Battery"),
            ("zh-Hans", "电池"),
            ("zh-Hant", "電池"),
            ("ja", "バッテリー"),
            ("fr", "Batterie"),
            ("de", "Batterie"),
            ("es", "Batería")
        ]

        for (identifier, value) in expected {
            let resource = LocalizedStringResource(
                "battery",
                locale: Locale(identifier: identifier),
                bundle: DuoText.bundle
            )
            XCTAssertEqual(
                String(localized: resource),
                value,
                identifier
            )
        }
    }

    func testDynamicResourcesKeepTheirLocalizedFormat() {
        let resource = LocalizedStringResource(
            "battery_charging",
            defaultValue: "\(82)% · Charging",
            locale: Locale(identifier: "zh-Hans"),
            bundle: DuoText.bundle
        )
        XCTAssertEqual(
            String(localized: resource),
            "82% · 充电中"
        )
    }

    func testWiFiSignalAccessibilityTextIsLocalized() {
        let expected: [(String, String)] = [
            ("en", "Battery 80%, Wi‑Fi connected, Wi‑Fi signal strength: 3 of 4 bars"),
            ("zh-Hans", "电量 80%，Wi‑Fi 已连接，Wi‑Fi 信号强度 3 格（共 4 格）"),
            ("zh-Hant", "電量 80%，Wi‑Fi 已連線，Wi‑Fi 訊號強度 3 格（共 4 格）"),
            ("ja", "バッテリー 80%、Wi‑Fi 接続済み、Wi‑Fi 信号強度は 4 段階中 3 段階"),
            ("fr", "Batterie à 80%, Wi‑Fi connecté, intensité du signal Wi‑Fi : 3 barres sur 4"),
            ("de", "Batterie 80%, Wi‑Fi verbunden, Wi‑Fi-Signalstärke: 3 von 4 Balken"),
            ("es", "Batería al 80%, Wi‑Fi conectado, intensidad de la señal Wi‑Fi: 3 de 4 barras")
        ]

        for (identifier, value) in expected {
            let locale = Locale(identifier: identifier)
            let baseLabelResource = LocalizedStringResource(
                "status_battery_connected",
                defaultValue: "Battery \(80)%, Wi‑Fi connected",
                locale: locale,
                bundle: DuoText.bundle
            )
            let baseLabel = String(localized: baseLabelResource)
            let resource = LocalizedStringResource(
                "accessibility_wifi_signal",
                defaultValue: "\(baseLabel), Wi‑Fi signal strength: \(3) of 4 bars",
                locale: locale,
                bundle: DuoText.bundle
            )
            XCTAssertEqual(String(localized: resource), value, identifier)
        }
    }

    func testWiFiColorControlIsLocalized() {
        let expected: [(String, String, String)] = [
            ("en", "Appearance", "Wi‑Fi Signal Color"),
            ("zh-Hans", "外观", "Wi‑Fi 信号颜色"),
            ("zh-Hant", "外觀", "Wi‑Fi 訊號顏色"),
            ("ja", "外観", "Wi‑Fi 信号の色"),
            ("fr", "Apparence", "Couleur du signal Wi‑Fi"),
            ("de", "Darstellung", "Wi‑Fi-Signalfarbe"),
            ("es", "Apariencia", "Color de la señal Wi‑Fi")
        ]

        for (identifier, appearanceValue, wifiColorValue) in expected {
            let locale = Locale(identifier: identifier)
            let appearance = LocalizedStringResource("appearance", locale: locale, bundle: DuoText.bundle)
            let wifiColor = LocalizedStringResource("wifi_signal_color", locale: locale, bundle: DuoText.bundle)
            XCTAssertEqual(String(localized: appearance), appearanceValue, identifier)
            XCTAssertEqual(String(localized: wifiColor), wifiColorValue, identifier)
        }
    }
}
