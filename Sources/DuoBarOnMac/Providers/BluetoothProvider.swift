import Foundation
import IOBluetooth

@MainActor
final class BluetoothProvider: NSObject {
    var onUpdate: ((BluetoothState) -> Void)?

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var powerObservers: [NSObjectProtocol] = []

    func start() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleConnected(_:device:))
        )
        let center = NotificationCenter.default
        powerObservers = [
            center.addObserver(forName: .IOBluetoothHostControllerPoweredOn, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            },
            center.addObserver(forName: .IOBluetoothHostControllerPoweredOff, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        ]
        refresh()
    }

    func refresh() {
        let availability = controllerAvailability()
        guard availability == .available else {
            disconnectNotifications.values.forEach { $0.unregister() }
            disconnectNotifications.removeAll()
            onUpdate?(BluetoothState(availability: availability))
            return
        }

        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        let connected: [BluetoothDeviceState] = paired
            .filter { $0.isConnected() }
            .compactMap { device in
                guard let id = device.addressString else { return nil }
                return BluetoothDeviceState(id: id, name: device.nameOrAddress)
            }
            .sorted { $0.id < $1.id }

        for device in paired where device.isConnected() {
            registerDisconnect(for: device)
        }
        let connectedIDs = Set(connected.map { $0.id })
        let staleIDs = disconnectNotifications.keys.filter { !connectedIDs.contains($0) }
        for id in staleIDs {
            disconnectNotifications[id]?.unregister()
            disconnectNotifications[id] = nil
        }
        onUpdate?(BluetoothState(availability: availability, connectedDevices: connected))
    }

    private func controllerAvailability() -> BluetoothAvailability {
        switch IOBluetoothHostController.default().powerState {
        case kBluetoothHCIPowerStateON: return .available
        case kBluetoothHCIPowerStateOFF: return .unavailable
        default: return .unknown
        }
    }

    @objc private func handleConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        registerDisconnect(for: device)
        refresh()
    }

    @objc private func handleDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let id = device.addressString else {
            refresh()
            return
        }
        disconnectNotifications[id]?.unregister()
        disconnectNotifications[id] = nil
        refresh()
    }

    private func registerDisconnect(for device: IOBluetoothDevice) {
        guard let id = device.addressString else { return }
        guard disconnectNotifications[id] == nil else { return }
        disconnectNotifications[id] = device.register(
            forDisconnectNotification: self,
            selector: #selector(handleDisconnected(_:device:))
        )
    }

    deinit {
        connectNotification?.unregister()
        disconnectNotifications.values.forEach { $0.unregister() }
        powerObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
