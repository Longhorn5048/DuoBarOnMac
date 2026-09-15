import Foundation

enum DuoText {
    static let bundle = Bundle.module

    static let centerDisplay = resource("center_display", defaultValue: "Center Display")
    static let wifi = resource("wifi", defaultValue: "Wi‑Fi")
    static let battery = resource("battery", defaultValue: "Battery")
    static let bluetooth = resource("bluetooth", defaultValue: "Bluetooth")
    static let charging = resource("charging", defaultValue: "Charging")
    static let chargingPaused = resource("charging_paused", defaultValue: "Charging Paused")
    static let fullyCharged = resource("fully_charged", defaultValue: "Fully Charged")
    static let connected = resource("connected", defaultValue: "Connected")
    static let notConnected = resource("not_connected", defaultValue: "Not Connected")
    static let off = resource("off", defaultValue: "Off")
    static let statusHints = resource("status_hints", defaultValue: "Status Hints")
    static let launchAtLogin = resource("launch_at_login", defaultValue: "Launch at Login")
    static let systemIcons = resource("system_icons", defaultValue: "System Icons…")
    static let systemIconsHelp = resource(
        "system_icons_help",
        defaultValue: "Hide battery and Wi‑Fi icons in System Settings"
    )
    static let quit = resource("quit", defaultValue: "Quit")
    static let unknown = resource("unknown", defaultValue: "—")

    static let statusItemLabel = resource(
        "status_item_label",
        defaultValue: "DuoBar battery and Wi‑Fi status"
    )

    static let eventChargingStarted = resource(
        "event_charging_started",
        defaultValue: "Charging started"
    )
    static let eventFullyCharged = resource(
        "event_fully_charged",
        defaultValue: "Battery fully charged"
    )
    static let eventChargingPaused = resource(
        "event_charging_paused",
        defaultValue: "Power connected, charging paused"
    )
    static let eventUnplugged = resource(
        "event_unplugged",
        defaultValue: "Power disconnected"
    )
    static let eventBluetoothConnected = resource(
        "event_bluetooth_connected",
        defaultValue: "Bluetooth device connected"
    )
    static let eventBluetoothDisconnected = resource(
        "event_bluetooth_disconnected",
        defaultValue: "Bluetooth device disconnected"
    )
    static let eventWiFiConnected = resource(
        "event_wifi_connected",
        defaultValue: "Wi‑Fi connected"
    )
    static let eventWiFiDisconnected = resource(
        "event_wifi_disconnected",
        defaultValue: "Wi‑Fi disconnected"
    )

    static let glyphChargingStarted = resource(
        "glyph_charging_started",
        defaultValue: "DuoBar, charging started"
    )
    static let glyphFullyCharged = resource(
        "glyph_fully_charged",
        defaultValue: "DuoBar, battery fully charged"
    )
    static let glyphChargingPaused = resource(
        "glyph_charging_paused",
        defaultValue: "DuoBar, power connected, charging paused"
    )
    static let glyphUnplugged = resource(
        "glyph_unplugged",
        defaultValue: "DuoBar, power disconnected"
    )
    static let glyphBluetoothConnected = resource(
        "glyph_bluetooth_connected",
        defaultValue: "DuoBar, Bluetooth device connected"
    )
    static let glyphBluetoothDisconnected = resource(
        "glyph_bluetooth_disconnected",
        defaultValue: "DuoBar, Bluetooth device disconnected"
    )
    static let glyphWiFiConnected = resource(
        "glyph_wifi_connected",
        defaultValue: "DuoBar, Wi‑Fi connected"
    )
    static let glyphWiFiDisconnected = resource(
        "glyph_wifi_disconnected",
        defaultValue: "DuoBar, Wi‑Fi disconnected"
    )

    static let accessibilityPermissionError = resource(
        "accessibility_permission_error",
        defaultValue: "Allow DuoBar in Accessibility settings before trying again"
    )
    static let controlCenterUnavailableError = resource(
        "control_center_unavailable_error",
        defaultValue: "System Control Center is not running"
    )
    static let nativeMenuUnavailableError = resource(
        "native_menu_unavailable_error",
        defaultValue: "Could not access the native menu; show the corresponding icon in System Settings first"
    )

    static func batteryValue(percent: Int?, status: PowerStatus) -> String {
        guard let percent else { return resolve(unknown) }
        return resolve(batteryValueResource(percent: percent, status: status))
    }

    static func batteryValueResource(percent: Int, status: PowerStatus) -> LocalizedStringResource {
        switch status {
        case .charging:
            return resource("battery_charging", defaultValue: "\(percent)% · Charging")
        case .connectedPaused:
            return resource("battery_charging_paused", defaultValue: "\(percent)% · Charging Paused")
        case .charged:
            return resource("battery_fully_charged", defaultValue: "\(percent)% · Fully Charged")
        default:
            return resource("battery_percent", defaultValue: "\(percent)%")
        }
    }

    static func bluetoothDevices(count: Int) -> String {
        resolve(resource("bluetooth_devices", defaultValue: "\(count) devices"))
    }

    static func eventMessage(kind: TransientEventKind, names: [String] = []) -> String {
        switch kind {
        case .chargingStarted: return resolve(eventChargingStarted)
        case .fullyCharged: return resolve(eventFullyCharged)
        case .chargingPaused: return resolve(eventChargingPaused)
        case .unplugged: return resolve(eventUnplugged)
        case .bluetoothConnected:
            guard !names.isEmpty else { return resolve(eventBluetoothConnected) }
            return resolve(resource(
                "event_bluetooth_connected_named",
                defaultValue: "Bluetooth device connected: \(names.formatted())"
            ))
        case .bluetoothDisconnected:
            guard !names.isEmpty else { return resolve(eventBluetoothDisconnected) }
            return resolve(resource(
                "event_bluetooth_disconnected_named",
                defaultValue: "Bluetooth device disconnected: \(names.formatted())"
            ))
        case .wifiConnected: return resolve(eventWiFiConnected)
        case .wifiDisconnected: return resolve(eventWiFiDisconnected)
        }
    }

    static func glyphAccessibility(_ snapshot: GlyphSnapshot) -> String {
        if let transient = snapshot.transientPresentation {
            switch transient.kind {
            case .chargingStarted: return resolve(glyphChargingStarted)
            case .fullyCharged: return resolve(glyphFullyCharged)
            case .chargingPaused: return resolve(glyphChargingPaused)
            case .unplugged: return resolve(glyphUnplugged)
            case .bluetoothConnected: return resolve(glyphBluetoothConnected)
            case .bluetoothDisconnected: return resolve(glyphBluetoothDisconnected)
            case .wifiConnected: return resolve(glyphWiFiConnected)
            case .wifiDisconnected: return resolve(glyphWiFiDisconnected)
            }
        }

        guard let percent = snapshot.batteryPercent else {
            return resolve(glyphUnknownResource(snapshot.wifiStatus))
        }
        return resolve(glyphStatusResource(
            wifiStatus: snapshot.wifiStatus,
            percent: percent,
            charging: snapshot.powerStatus == .charging
        ))
    }

    static func statusItemAccessibility(_ snapshot: GlyphSnapshot) -> String {
        if let transient = snapshot.transientPresentation {
            return eventAccessibility(kind: transient.kind, names: transient.entityNames)
        }

        guard let percent = snapshot.batteryPercent else {
            return resolve(statusUnknownResource(snapshot.wifiStatus))
        }
        return resolve(statusResource(
            wifiStatus: snapshot.wifiStatus,
            percent: percent,
            charging: snapshot.powerStatus == .charging
        ))
    }

    static func eventAccessibility(kind: TransientEventKind, names: [String]) -> String {
        switch kind {
        case .chargingStarted: return resolve(glyphChargingStarted)
        case .fullyCharged: return resolve(glyphFullyCharged)
        case .chargingPaused: return resolve(glyphChargingPaused)
        case .unplugged: return resolve(glyphUnplugged)
        case .bluetoothConnected:
            guard !names.isEmpty else { return resolve(glyphBluetoothConnected) }
            return resolve(resource(
                "accessibility_bluetooth_connected_named",
                defaultValue: "DuoBar, Bluetooth device connected: \(names.formatted())"
            ))
        case .bluetoothDisconnected:
            guard !names.isEmpty else { return resolve(glyphBluetoothDisconnected) }
            return resolve(resource(
                "accessibility_bluetooth_disconnected_named",
                defaultValue: "DuoBar, Bluetooth device disconnected: \(names.formatted())"
            ))
        case .wifiConnected: return resolve(glyphWiFiConnected)
        case .wifiDisconnected: return resolve(glyphWiFiDisconnected)
        }
    }

    static func resolve(_ resource: LocalizedStringResource) -> String {
        return String(localized: resource)
    }

    private static func glyphUnknownResource(_ status: WiFiStatus) -> LocalizedStringResource {
        switch status {
        case .connected:
            return resource("glyph_battery_unknown_connected", defaultValue: "DuoBar, Battery unknown, Wi‑Fi connected")
        case .disconnected:
            return resource("glyph_battery_unknown_disconnected", defaultValue: "DuoBar, Battery unknown, Wi‑Fi not connected")
        case .disabled:
            return resource("glyph_battery_unknown_off", defaultValue: "DuoBar, Battery unknown, Wi‑Fi off")
        case .unknown:
            return resource("glyph_battery_unknown_unknown", defaultValue: "DuoBar, Battery unknown, Wi‑Fi unknown")
        }
    }

    private static func statusUnknownResource(_ status: WiFiStatus) -> LocalizedStringResource {
        switch status {
        case .connected:
            return resource("status_battery_unknown_connected", defaultValue: "Battery unknown, Wi‑Fi connected")
        case .disconnected:
            return resource("status_battery_unknown_disconnected", defaultValue: "Battery unknown, Wi‑Fi not connected")
        case .disabled:
            return resource("status_battery_unknown_off", defaultValue: "Battery unknown, Wi‑Fi off")
        case .unknown:
            return resource("status_battery_unknown_unknown", defaultValue: "Battery unknown, Wi‑Fi unknown")
        }
    }

    private static func glyphStatusResource(
        wifiStatus: WiFiStatus,
        percent: Int,
        charging: Bool
    ) -> LocalizedStringResource {
        switch (wifiStatus, charging) {
        case (.connected, false):
            return resource("glyph_battery_connected", defaultValue: "DuoBar, Battery \(percent)%, Wi‑Fi connected")
        case (.disconnected, false):
            return resource("glyph_battery_disconnected", defaultValue: "DuoBar, Battery \(percent)%, Wi‑Fi not connected")
        case (.disabled, false):
            return resource("glyph_battery_off", defaultValue: "DuoBar, Battery \(percent)%, Wi‑Fi off")
        case (.unknown, false):
            return resource("glyph_battery_unknown", defaultValue: "DuoBar, Battery \(percent)%, Wi‑Fi unknown")
        case (.connected, true):
            return resource("glyph_battery_charging_connected", defaultValue: "DuoBar, Battery \(percent)%, Wi‑Fi connected, Charging")
        case (.disconnected, true):
            return resource("glyph_battery_charging_disconnected", defaultValue: "DuoBar, Battery \(percent)%, Wi‑Fi not connected, Charging")
        case (.disabled, true):
            return resource("glyph_battery_charging_off", defaultValue: "DuoBar, Battery \(percent)%, Wi‑Fi off, Charging")
        case (.unknown, true):
            return resource("glyph_battery_charging_unknown", defaultValue: "DuoBar, Battery \(percent)%, Wi‑Fi unknown, Charging")
        }
    }

    private static func statusResource(
        wifiStatus: WiFiStatus,
        percent: Int,
        charging: Bool
    ) -> LocalizedStringResource {
        switch (wifiStatus, charging) {
        case (.connected, false):
            return resource("status_battery_connected", defaultValue: "Battery \(percent)%, Wi‑Fi connected")
        case (.disconnected, false):
            return resource("status_battery_disconnected", defaultValue: "Battery \(percent)%, Wi‑Fi not connected")
        case (.disabled, false):
            return resource("status_battery_off", defaultValue: "Battery \(percent)%, Wi‑Fi off")
        case (.unknown, false):
            return resource("status_battery_unknown", defaultValue: "Battery \(percent)%, Wi‑Fi unknown")
        case (.connected, true):
            return resource("status_battery_charging_connected", defaultValue: "Battery \(percent)%, Wi‑Fi connected, Charging")
        case (.disconnected, true):
            return resource("status_battery_charging_disconnected", defaultValue: "Battery \(percent)%, Wi‑Fi not connected, Charging")
        case (.disabled, true):
            return resource("status_battery_charging_off", defaultValue: "Battery \(percent)%, Wi‑Fi off, Charging")
        case (.unknown, true):
            return resource("status_battery_charging_unknown", defaultValue: "Battery \(percent)%, Wi‑Fi unknown, Charging")
        }
    }

    private static func resource(
        _ key: StaticString,
        defaultValue: String.LocalizationValue
    ) -> LocalizedStringResource {
        LocalizedStringResource(key, defaultValue: defaultValue, bundle: .module)
    }

}
