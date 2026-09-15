import CoreWLAN
import Foundation
import Network

@MainActor
final class WiFiProvider: NSObject, CWEventDelegate {
    var onUpdate: ((WiFiState) -> Void)?

    private let client = CWWiFiClient.shared()
    private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let monitorQueue = DispatchQueue(label: "DuoBarOnMac.WiFiMonitor")
    private var pathStatus: NWPath.Status = .requiresConnection
    private var timer: Timer?

    func start() {
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

    func refresh() {
        guard let interface = client.interface() else {
            onUpdate?(WiFiState(status: .unknown))
            return
        }

        guard interface.powerOn() else {
            onUpdate?(WiFiState(status: .disabled, internetAvailable: false))
            return
        }

        let rssi = interface.rssiValue()
        let associated = rssi < 0
        guard associated else {
            onUpdate?(WiFiState(status: .disconnected, rssi: nil, internetAvailable: false))
            return
        }

        onUpdate?(WiFiState(
            status: .connected,
            name: interface.ssid(),
            rssi: rssi,
            internetAvailable: pathStatus == .satisfied
        ))
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
        timer?.invalidate()
        pathMonitor.cancel()
    }
}
