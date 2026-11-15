import AppKit
import CoreLocation
import CoreWLAN
import Foundation
import Network

@MainActor
final class WiFiProvider: NSObject, CWEventDelegate, CLLocationManagerDelegate {
    var onUpdate: ((WiFiState) -> Void)?

    private let client = CWWiFiClient.shared()
    private let locationManager = CLLocationManager()
    private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let monitorQueue = DispatchQueue(label: "DuoBarOnMac.WiFiMonitor")
    private var pathStatus: NWPath.Status = .requiresConnection
    private var timer: Timer?
    private var pendingNameAuthorization = false

    func start() {
        locationManager.delegate = self
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil
        )
        client.delegate = self
        for eventType in [
            CWEventType.powerDidChange,
            CWEventType.ssidDidChange,
            CWEventType.bssidDidChange,
            CWEventType.linkDidChange,
            CWEventType.linkQualityDidChange
        ] {
            try? client.startMonitoringEvent(with: eventType)
        }
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.pathStatus = path.status
                self?.refresh()
            }
        }
        pathMonitor.start(queue: monitorQueue)
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        timer?.tolerance = 10
    }

    func requestNameAccess() {
        switch nameAccess {
        case .notRequested:
            // Accessory apps must become active before macOS can present the prompt.
            pendingNameAuthorization = true
            NSApp.activate()
            requestPendingNameAuthorization()
        case .denied, .servicesDisabled:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                NSWorkspace.shared.open(url)
            }
        case .allowed:
            break
        }
        refresh()
    }

    @objc private func applicationDidBecomeActive() {
        requestPendingNameAuthorization()
        refresh()
    }

    private func requestPendingNameAuthorization() {
        guard pendingNameAuthorization, NSApp.isActive else { return }
        pendingNameAuthorization = false
        guard nameAccess == .notRequested else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    private var nameAccess: WiFiNameAccess {
        Self.nameAccess(
            authorization: locationManager.authorizationStatus,
            servicesEnabled: CLLocationManager.locationServicesEnabled()
        )
    }

    static func nameAccess(authorization: CLAuthorizationStatus, servicesEnabled: Bool) -> WiFiNameAccess {
        guard servicesEnabled else { return .servicesDisabled }
        switch authorization {
        case .notDetermined: return .notRequested
        case .authorizedAlways, .authorizedWhenInUse: return .allowed
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    @objc func refresh() {
        let access = nameAccess
        guard let interface = client.interface() else {
            onUpdate?(WiFiState(status: .unknown, nameAccess: access))
            return
        }

        guard interface.powerOn() else {
            onUpdate?(WiFiState(status: .disabled, internetAvailable: false, nameAccess: access))
            return
        }

        let rssi = interface.rssiValue()
        let associated = rssi < 0
        guard associated else {
            onUpdate?(WiFiState(status: .disconnected, rssi: nil, internetAvailable: false, nameAccess: access))
            return
        }

        onUpdate?(WiFiState(
            status: .connected,
            name: access == .allowed ? interface.ssid() : nil,
            rssi: rssi,
            internetAvailable: pathStatus == .satisfied,
            nameAccess: access
        ))
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshFromEvent()
    }

    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        refreshFromEvent()
    }

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        refreshFromEvent()
    }

    nonisolated func bssidDidChangeForWiFiInterface(withName interfaceName: String) {
        refreshFromEvent()
    }

    nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        refreshFromEvent()
    }

    nonisolated func linkQualityDidChangeForWiFiInterface(
        withName interfaceName: String,
        rssi: Int,
        transmitRate: Double
    ) {
        refreshFromEvent()
    }

    private nonisolated func refreshFromEvent() {
        Task { @MainActor [weak self] in
            self?.refresh()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
        pathMonitor.cancel()
    }
}
