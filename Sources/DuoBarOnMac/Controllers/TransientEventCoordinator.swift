import AppKit
import QuartzCore

struct TransientEvent: Equatable {
    let kind: TransientEventKind
    let entityNames: [String]
    let sourceKey: String
    let createdAt: Date
    let expiresAt: Date

    var priority: Int { kind.priority }

    func isValid(at date: Date) -> Bool {
        date < expiresAt
    }
}

@MainActor
final class TransientEventCoordinator {
    private let model: PresentationState
    private var activeEvent: TransientEvent?
    private var pendingEvents: [TransientEvent] = []
    private var lastEventTimes: [String: Date] = [:]
    private var timer: Timer?
    private var activeStart: Date?
    private var bluetoothDebounceTimer: Timer?
    private var pendingBluetoothBaseline: BluetoothState?
    private var pendingBluetoothTarget: BluetoothState?

#if DEBUG
    var activeEventKindForTesting: TransientEventKind? { activeEvent?.kind }
    var pendingEventCountForTesting: Int { pendingEvents.count }

    func flushPendingBluetoothForTesting(now: Date) {
        flushBluetoothChange(now: now)
    }
#endif

    private let duration: TimeInterval = 1.26
    private let deduplicationWindow: TimeInterval = 2
    private let expirationWindow: TimeInterval = 5

    init(model: PresentationState) {
        self.model = model
    }

    func handleBatteryChange(from old: BatteryState, to new: BatteryState, now: Date = Date()) {
        guard old.availability != .unknown else { return }
        switch (old.powerStatus, new.powerStatus) {
        case (.charging, .charged):
            ingest(kind: .fullyCharged, sourceKey: "power:charged", now: now)
        case (.charging, .connectedPaused), (.onBattery, .connectedPaused):
            ingest(kind: .chargingPaused, sourceKey: "power:paused", now: now)
        case (.charging, .onBattery), (.connectedPaused, .onBattery), (.charged, .onBattery):
            ingest(kind: .unplugged, sourceKey: "power:unplugged", now: now)
        case (_, .charging) where old.powerStatus != .charging:
            ingest(kind: .chargingStarted, sourceKey: "power:charging", now: now)
        default:
            break
        }
    }

    func handleWiFiChange(from old: WiFiState, to new: WiFiState, now: Date = Date()) {
        guard old.status != .unknown else { return }
        let wasConnected = old.status == .connected
        let isConnected = new.status == .connected
        if !wasConnected, isConnected {
            ingest(kind: .wifiConnected, sourceKey: "wifi:connected", now: now)
        } else if wasConnected, !isConnected {
            ingest(kind: .wifiDisconnected, sourceKey: "wifi:disconnected", now: now)
        }
    }

    func handleBluetoothChange(from old: BluetoothState, to new: BluetoothState, now: Date = Date()) {
        guard model.eventHintsEnabled, old.availability != .unknown else { return }
        guard hasBluetoothConnectionDelta(from: old, to: new) else {
            if bluetoothDebounceTimer != nil {
                pendingBluetoothTarget = new
                cancelBluetoothDebounceIfSettled()
            }
            return
        }

        if bluetoothDebounceTimer != nil {
            pendingBluetoothTarget = new
            cancelBluetoothDebounceIfSettled()
            return
        }

        pendingBluetoothBaseline = old
        pendingBluetoothTarget = new
        bluetoothDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.flushBluetoothChange(now: Date())
            }
        }
    }

    private func flushBluetoothChange(now: Date) {
        bluetoothDebounceTimer?.invalidate()
        bluetoothDebounceTimer = nil
        guard let old = pendingBluetoothBaseline, let new = pendingBluetoothTarget else {
            pendingBluetoothBaseline = nil
            pendingBluetoothTarget = nil
            return
        }
        pendingBluetoothBaseline = nil
        pendingBluetoothTarget = nil

        let oldIDs = Set(old.connectedDevices.map(\.id))
        let newIDs = Set(new.connectedDevices.map(\.id))
        let connected = new.connectedDevices.filter { !oldIDs.contains($0.id) }.map(\.name)
        let disconnected = old.connectedDevices.filter { !newIDs.contains($0.id) }.map(\.name)

        if !connected.isEmpty {
            ingest(kind: .bluetoothConnected, entityNames: connected, sourceKey: "bluetooth:connected:\(connected.sorted().joined(separator: "|"))", now: now)
        }
        if !disconnected.isEmpty {
            ingest(kind: .bluetoothDisconnected, entityNames: disconnected, sourceKey: "bluetooth:disconnected:\(disconnected.sorted().joined(separator: "|"))", now: now)
        }
    }

    private func hasBluetoothConnectionDelta(from old: BluetoothState, to new: BluetoothState) -> Bool {
        Set(old.connectedDevices.map(\.id)) != Set(new.connectedDevices.map(\.id))
    }

    private func cancelBluetoothDebounceIfSettled() {
        guard let baseline = pendingBluetoothBaseline,
              let target = pendingBluetoothTarget,
              !hasBluetoothConnectionDelta(from: baseline, to: target) else { return }
        bluetoothDebounceTimer?.invalidate()
        bluetoothDebounceTimer = nil
        pendingBluetoothBaseline = nil
        pendingBluetoothTarget = nil
    }

    func ingest(
        kind: TransientEventKind,
        entityNames: [String] = [],
        sourceKey: String,
        now: Date = Date()
    ) {
        guard model.eventHintsEnabled else { return }
        purgeExpired(now: now)

        guard lastEventTimes[sourceKey].map({ now.timeIntervalSince($0) >= deduplicationWindow }) ?? true else {
            return
        }
        lastEventTimes[sourceKey] = now

        let event = TransientEvent(
            kind: kind,
            entityNames: entityNames,
            sourceKey: sourceKey,
            createdAt: now,
            expiresAt: now.addingTimeInterval(expirationWindow)
        )

        if let activeEvent, !activeEvent.isValid(at: now) {
            stopActive()
            startNext(now: now)
        }

        if let activeEvent {
            if event.priority > activeEvent.priority || shouldPreempt(active: activeEvent, with: event) {
                stopActive()
                start(event, now: now)
            } else if pendingEvents.count < 3 {
                pendingEvents.append(event)
            }
        } else {
            start(event, now: now)
        }
    }

    func cancelForModeSwitch() {
        stopActive()
        pendingEvents.removeAll()
        bluetoothDebounceTimer?.invalidate()
        bluetoothDebounceTimer = nil
        pendingBluetoothBaseline = nil
        pendingBluetoothTarget = nil
    }

    private func start(_ event: TransientEvent, now: Date) {
        guard event.isValid(at: now) else { return }
        activeEvent = event
        activeStart = now
        updatePresentation(progress: 0, event: event)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick(now: Date = Date()) {
        guard let activeEvent, let activeStart else {
            stopActive()
            return
        }

        guard activeEvent.isValid(at: now) else {
            stopActive()
            startNext(now: now)
            return
        }

        let progress = min(max(now.timeIntervalSince(activeStart) / duration, 0), 1)
        updatePresentation(progress: progress, event: activeEvent)
        if progress >= 1 {
            stopActive()
            startNext(now: now)
        }
    }

    private func startNext(now: Date) {
        purgeExpired(now: now)
        guard !pendingEvents.isEmpty else { return }
        let highestPriority = pendingEvents.map(\.priority).max() ?? 0
        let nextIndex = pendingEvents.firstIndex { $0.priority == highestPriority } ?? 0
        let next = pendingEvents.remove(at: nextIndex)
        start(next, now: now)
    }

    private func shouldPreempt(active: TransientEvent, with incoming: TransientEvent) -> Bool {
        guard incoming.kind == .unplugged else { return false }
        return [.chargingStarted, .chargingPaused, .fullyCharged].contains(active.kind)
    }

    private func updatePresentation(progress: Double, event: TransientEvent) {
        model.transientPresentation = TransientPresentation(
            kind: event.kind,
            entityNames: event.entityNames,
            progress: progress
        )
    }

    private func stopActive() {
        timer?.invalidate()
        timer = nil
        activeEvent = nil
        activeStart = nil
        model.transientPresentation = nil
    }

    private func purgeExpired(now: Date) {
        pendingEvents.removeAll { !$0.isValid(at: now) }
        lastEventTimes = lastEventTimes.filter { now.timeIntervalSince($0.value) < expirationWindow }
    }

    deinit {
        timer?.invalidate()
        bluetoothDebounceTimer?.invalidate()
    }
}

