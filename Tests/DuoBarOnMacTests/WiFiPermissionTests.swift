import CoreLocation
import XCTest
@testable import DuoBarOnMac

@MainActor
final class WiFiPermissionTests: XCTestCase {
    func testUndecidedAndDeniedAccessRemainActionable() {
        XCTAssertEqual(WiFiProvider.nameAccess(authorization: .notDetermined, servicesEnabled: true), .notRequested)
        XCTAssertEqual(WiFiProvider.nameAccess(authorization: .denied, servicesEnabled: true), .denied)
        XCTAssertEqual(WiFiProvider.nameAccess(authorization: .restricted, servicesEnabled: true), .denied)
    }

    func testGrantedMacOSAuthorizationPermitsSSIDReads() {
        XCTAssertEqual(WiFiProvider.nameAccess(authorization: .authorizedAlways, servicesEnabled: true), .allowed)
    }

    func testDisabledLocationServicesOverridePriorAppAuthorization() {
        for authorization in [CLAuthorizationStatus.notDetermined, .denied, .authorizedAlways] {
            XCTAssertEqual(WiFiProvider.nameAccess(authorization: authorization, servicesEnabled: false), .servicesDisabled)
        }
    }
}
