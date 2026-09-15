import AppKit
import Foundation
import IOKit.ps

@MainActor
final class PowerProvider {
    var onUpdate: ((BatteryState) -> Void)?

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var powerSourceRunLoopSource: CFRunLoopSource?

    func start() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource(Self.powerSourceDidChange, context)?.takeRetainedValue()
        if let powerSourceRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .defaultMode)
        } else {
            // Notifications normally provide updates; poll only if registration fails.
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            timer?.tolerance = 10
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        let state = readState()
        onUpdate?(state)
    }

    private func readState() -> BatteryState {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sourceList = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        for source in sourceList {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                (description[kIOPSIsPresentKey] as? Bool ?? true)
            else { continue }

            return Self.state(from: description)
        }

        return BatteryState(availability: .unavailable, percent: nil, powerStatus: .unknown)
    }

    static func state(from description: [String: Any]) -> BatteryState {
        let current = description[kIOPSCurrentCapacityKey] as? Int
        let maximum = description[kIOPSMaxCapacityKey] as? Int
        let percent: Int?
        if let current, let maximum, maximum > 0 {
            percent = min(max((current * 100) / maximum, 0), 100)
        } else {
            percent = nil
        }

        let isCharging = description[kIOPSIsChargingKey] as? Bool
        let sourceState = description[kIOPSPowerSourceStateKey] as? String
        let isCharged = description[kIOPSIsChargedKey] as? Bool
        let powerStatus: PowerStatus
        if isCharging == true {
            powerStatus = .charging
        } else if sourceState == kIOPSACPowerValue, isCharged == true {
            powerStatus = .charged
        } else if sourceState == kIOPSACPowerValue, isCharging == false, let percent {
            powerStatus = percent < 100 ? .connectedPaused : .charged
        } else if sourceState == kIOPSBatteryPowerValue {
            powerStatus = .onBattery
        } else {
            // Missing keys are not evidence of AC, charging, or 100% capacity.
            powerStatus = .unknown
        }

        return BatteryState(
            availability: .available,
            percent: percent,
            powerStatus: powerStatus,
            minutesToFull: chargeMinutes(description[kIOPSTimeToFullChargeKey] as? Int, status: powerStatus),
            isFinishingCharge: powerStatus == .charging && description[kIOPSIsFinishingChargeKey] as? Bool == true
        )
    }

    static func chargeMinutes(_ value: Int?, status: PowerStatus) -> Int? {
        guard status == .charging, let value, value > 0 else { return nil }
        return value
    }

    private static let powerSourceDidChange: IOPowerSourceCallbackType = { context in
        guard let context else { return }
        let provider = Unmanaged<PowerProvider>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in
            provider.refresh()
        }
    }

    deinit {
        timer?.invalidate()
        if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .defaultMode)
            CFRunLoopSourceInvalidate(powerSourceRunLoopSource)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
