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
}
