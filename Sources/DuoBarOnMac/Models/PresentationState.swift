import Foundation
import Observation

enum CenterMode: Int, CaseIterable, Codable, Equatable, Identifiable {
    case wifi = 0
    case battery = 1

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .wifi: "Wi‑Fi"
        case .battery: "电量"
        }
    }
}

enum BatteryAvailability: Equatable {
    case available
    case unavailable
    case unknown
}

enum PowerStatus: Equatable {
    case onBattery
    case charging
    case connectedPaused
    case charged
    case unknown
}

struct BatteryState: Equatable {
    var availability: BatteryAvailability = .unknown
    var percent: Int?
    var powerStatus: PowerStatus = .unknown
    var minutesToFull: Int?
    var isFinishingCharge = false

    var fraction: Double? {
        guard let percent else { return nil }
        return min(max(Double(percent) / 100.0, 0), 1)
    }
}

enum WiFiStatus: Equatable {
    case connected
    case disconnected
    case disabled
    case unknown
}

struct WiFiState: Equatable {
    var status: WiFiStatus = .unknown
    var name: String?
    var rssi: Int?
    var internetAvailable = false

    var strength: Int? {
        guard let rssi, rssi < 0 else { return nil }
        if rssi >= -55 { return 4 }
        if rssi >= -65 { return 3 }
        if rssi >= -75 { return 2 }
        return 1
    }
}

enum BluetoothAvailability: Equatable {
    case available
    case unavailable
    case unknown
}

struct BluetoothDeviceState: Equatable, Identifiable {
    let id: String
    let name: String
}

struct BluetoothState: Equatable {
    var availability: BluetoothAvailability = .unknown
    var connectedDevices: [BluetoothDeviceState] = []

    var connectedCount: Int { connectedDevices.count }
}

enum TransientEventKind: String, Equatable {
    case chargingStarted
    case fullyCharged
    case chargingPaused
    case unplugged
    case bluetoothConnected
    case bluetoothDisconnected
    case wifiConnected
    case wifiDisconnected

    var priority: Int {
        switch self {
        case .chargingStarted, .fullyCharged, .chargingPaused, .unplugged: return 3
        case .bluetoothConnected, .bluetoothDisconnected: return 2
        case .wifiConnected, .wifiDisconnected: return 1
        }
    }
}

struct TransientPresentation: Equatable {
    let kind: TransientEventKind
    let entityNames: [String]
    var progress: Double
}

final class AppPreferences {
    private let defaults: UserDefaults
    private let centerModeKey = "centerMode"
    private let eventHintsEnabledKey = "eventHintsEnabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var centerMode: CenterMode {
        get {
            guard let rawValue = defaults.object(forKey: centerModeKey) as? Int,
                  let mode = CenterMode(rawValue: rawValue) else {
                return .wifi
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: centerModeKey) }
    }

    var eventHintsEnabled: Bool {
        get {
            guard defaults.object(forKey: eventHintsEnabledKey) != nil else { return true }
            return defaults.bool(forKey: eventHintsEnabledKey)
        }
        set { defaults.set(newValue, forKey: eventHintsEnabledKey) }
    }
}

@MainActor
@Observable
final class PresentationState {
    var centerMode: CenterMode
    var battery = BatteryState()
    var wifi = WiFiState()
    var bluetooth = BluetoothState()
    var transitionProgress: CGFloat
    var chargingPulseOpacity = 1.0
    var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    var transientPresentation: TransientPresentation?
    var isPanelPresented = false
    var eventHintsEnabled: Bool

    private let preferences: AppPreferences

    init(preferences: AppPreferences = AppPreferences()) {
        self.preferences = preferences
        let mode = preferences.centerMode
        centerMode = mode
        transitionProgress = CGFloat(mode.rawValue)
        eventHintsEnabled = preferences.eventHintsEnabled
    }

    func setCenterMode(_ mode: CenterMode) {
        guard centerMode != mode else { return }
        centerMode = mode
        preferences.centerMode = mode
    }

    func setEventHintsEnabled(_ enabled: Bool) {
        guard eventHintsEnabled != enabled else { return }
        eventHintsEnabled = enabled
        preferences.eventHintsEnabled = enabled
    }

    var glyphSnapshot: GlyphSnapshot {
        GlyphSnapshot(
            batteryFraction: battery.fraction,
            batteryPercent: battery.percent,
            powerStatus: battery.powerStatus,
            batteryAvailability: battery.availability,
            wifiStatus: wifi.status,
            wifiStrength: wifi.strength,
            transitionProgress: transitionProgress,
            chargingPulseOpacity: chargingPulseOpacity,
            transientPresentation: transientPresentation,
            isLowPowerModeEnabled: isLowPowerModeEnabled
        )
    }
}

struct GlyphSnapshot: Equatable {
    let batteryFraction: Double?
    let batteryPercent: Int?
    let powerStatus: PowerStatus
    let batteryAvailability: BatteryAvailability
    let wifiStatus: WiFiStatus
    let wifiStrength: Int?
    let transitionProgress: CGFloat
    let chargingPulseOpacity: Double
    let transientPresentation: TransientPresentation?
    var isLowPowerModeEnabled: Bool = false

    var ringTone: BatteryRingTone {
        if powerStatus == .charging { return .charging }
        if let batteryPercent, batteryPercent < 10 { return .critical }
        if isLowPowerModeEnabled { return .lowPower }
        return .normal
    }

    var powerSymbol: String? {
        switch powerStatus {
        case .charging: return "bolt.fill"
        case .connectedPaused: return "pause.fill"
        case .charged: return "powerplug.fill"
        default: return nil
        }
    }
}

enum BatteryRingTone: Equatable {
    case normal, charging, critical, lowPower
}
