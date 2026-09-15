import AppKit
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: PresentationState!
    private var motion: MotionCoordinator!
    private var powerProvider: PowerProvider!
    private var wifiProvider: WiFiProvider!
    private var bluetoothProvider: BluetoothProvider!
    private var eventCoordinator: TransientEventCoordinator!
    private var powerModeObserver: NSObjectProtocol?
    private var statusItemController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        model = PresentationState()
        powerModeObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.model.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
        motion = MotionCoordinator(model: model)
        powerProvider = PowerProvider()
        wifiProvider = WiFiProvider()
        bluetoothProvider = BluetoothProvider()
        eventCoordinator = TransientEventCoordinator(model: model)
        motion.onModeTransition = { [weak self] in
            self?.eventCoordinator.cancelForModeSwitch()
        }

        powerProvider.onUpdate = { [weak self] state in
            guard let self else { return }
            self.model.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            let old = self.model.battery
            self.model.battery = state
            self.eventCoordinator.handleBatteryChange(from: old, to: state)
        }
        wifiProvider.onUpdate = { [weak self] state in
            guard let self else { return }
            let old = self.model.wifi
            self.model.wifi = state
            self.eventCoordinator.handleWiFiChange(from: old, to: state)
        }
        bluetoothProvider.onUpdate = { [weak self] state in
            guard let self else { return }
            let old = self.model.bluetooth
            self.model.bluetooth = state
            self.eventCoordinator.handleBluetoothChange(from: old, to: state)
        }

        powerProvider.start()
        wifiProvider.start()
        bluetoothProvider.start()

        statusItemController = StatusItemController(model: model, motion: motion)
        statusItemController.start()
    }
}

@main
struct DuoBarOnMacApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
