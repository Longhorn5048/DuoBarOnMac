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
        let expected: [(String, String, String)] = [
            ("en", "Battery 80%, Wi‑Fi connected, Wi‑Fi signal strength: 3 of 3 bars", "Battery 80%, Wi‑Fi connected, Wi‑Fi signal strength: 3 of 4 bars"),
            ("zh-Hans", "电量 80%，Wi‑Fi 已连接，Wi‑Fi 信号强度 3 格（共 3 格）", "电量 80%，Wi‑Fi 已连接，Wi‑Fi 信号强度 3 格（共 4 格）"),
            ("zh-Hant", "電量 80%，Wi‑Fi 已連線，Wi‑Fi 訊號強度 3 格（共 3 格）", "電量 80%，Wi‑Fi 已連線，Wi‑Fi 訊號強度 3 格（共 4 格）"),
            ("ja", "バッテリー 80%、Wi‑Fi 接続済み、Wi‑Fi 信号強度 3/3 段階", "バッテリー 80%、Wi‑Fi 接続済み、Wi‑Fi 信号強度 3/4 段階"),
            ("fr", "Batterie à 80%, Wi‑Fi connecté, intensité du signal Wi‑Fi : 3 barres sur 3", "Batterie à 80%, Wi‑Fi connecté, intensité du signal Wi‑Fi : 3 barres sur 4"),
            ("de", "Batterie 80%, Wi‑Fi verbunden, Wi‑Fi-Signalstärke: 3 von 3 Balken", "Batterie 80%, Wi‑Fi verbunden, Wi‑Fi-Signalstärke: 3 von 4 Balken"),
            ("es", "Batería al 80%, Wi‑Fi conectado, intensidad de la señal Wi‑Fi: 3 de 3 barras", "Batería al 80%, Wi‑Fi conectado, intensidad de la señal Wi‑Fi: 3 de 4 barras")
        ]

        for (identifier, threeDotsValue, fourDotsValue) in expected {
            let locale = Locale(identifier: identifier)
            let baseLabelResource = LocalizedStringResource(
                "status_battery_connected",
                defaultValue: "Battery \(80)%, Wi‑Fi connected",
                locale: locale,
                bundle: DuoText.bundle
            )
            let baseLabel = String(localized: baseLabelResource)
            XCTAssertEqual(
                String(localized: DuoText.wifiSignalAccessibilityResource(
                    label: baseLabel,
                    strength: 3,
                    dotCount: .three,
                    locale: locale
                )),
                threeDotsValue,
                identifier
            )
            XCTAssertEqual(
                String(localized: DuoText.wifiSignalAccessibilityResource(
                    label: baseLabel,
                    strength: 3,
                    dotCount: .four,
                    locale: locale
                )),
                fourDotsValue,
                identifier
            )
        }
    }

    func testWiFiColorControlIsLocalized() {
        let expected: [(String, String, String, String, String, String)] = [
            ("en", "Appearance", "Wi‑Fi Signal Dots", "Charging Color", "Battery Color", "Wi‑Fi Signal Color"),
            ("zh-Hans", "外观", "Wi‑Fi 信号点数", "充电颜色", "电池颜色", "Wi‑Fi 信号颜色"),
            ("zh-Hant", "外觀", "Wi‑Fi 訊號點數", "充電顏色", "電池顏色", "Wi‑Fi 訊號顏色"),
            ("ja", "外観", "Wi‑Fi 信号の点数", "充電時の色", "バッテリーの色", "Wi‑Fi 信号の色"),
            ("fr", "Apparence", "Nombre de points Wi‑Fi", "Couleur de charge", "Couleur de batterie", "Couleur du signal Wi‑Fi"),
            ("de", "Darstellung", "Anzahl der Wi‑Fi-Punkte", "Ladefarbe", "Batteriefarbe", "Wi‑Fi-Signalfarbe"),
            ("es", "Apariencia", "Puntos de señal Wi‑Fi", "Color de carga", "Color de batería", "Color de la señal Wi‑Fi")
        ]

        for (identifier, appearanceValue, dotCountValue, chargingColorValue, batteryColorValue, wifiColorValue) in expected {
            let locale = Locale(identifier: identifier)
            let appearance = LocalizedStringResource("appearance", locale: locale, bundle: DuoText.bundle)
            let dotCount = LocalizedStringResource("wifi_signal_dots", locale: locale, bundle: DuoText.bundle)
            let chargingColor = LocalizedStringResource("charging_color", locale: locale, bundle: DuoText.bundle)
            let batteryColor = LocalizedStringResource("battery_color", locale: locale, bundle: DuoText.bundle)
            let wifiColor = LocalizedStringResource("wifi_signal_color", locale: locale, bundle: DuoText.bundle)
            XCTAssertEqual(String(localized: appearance), appearanceValue, identifier)
            XCTAssertEqual(String(localized: dotCount), dotCountValue, identifier)
            XCTAssertEqual(String(localized: chargingColor), chargingColorValue, identifier)
            XCTAssertEqual(String(localized: batteryColor), batteryColorValue, identifier)
            XCTAssertEqual(String(localized: wifiColor), wifiColorValue, identifier)
        }
    }
}
