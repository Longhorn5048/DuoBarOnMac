import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: PresentationState
    private let motion: MotionCoordinator
    private let statusItem = NSStatusBar.system.statusItem(withLength: 28)
    private let imageRenderer = GlyphImageRenderer()
    private var lastAccessibilityValue: String?
    private var appearanceObservation: NSKeyValueObservation?
    private var panelController: DetailsPanelController?

    init(model: PresentationState, motion: MotionCoordinator) {
        self.model = model
        self.motion = motion
        super.init()
    }

    func start() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "DuoBar"
        button.setAccessibilityLabel("DuoBar 电池与 Wi‑Fi 状态")
        panelController = DetailsPanelController(
            model: model,
            motion: motion,
            launchAtLogin: LaunchAtLoginService(),
            statusButton: button
        )
        appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshGlyph() }
        }
        observeModel()
        refreshGlyph()
    }

    @objc private func togglePanel() {
        panelController?.toggle()
    }

    private func refreshGlyph() {
        guard let button = statusItem.button else { return }
        let snapshot = model.glyphSnapshot
        let dark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let image = imageRenderer.image(
            snapshot: snapshot,
            displaySize: menuGlyphSize(for: button),
            scale: button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2,
            dark: dark
        )
        if button.image !== image {
            image.isTemplate = false
            button.image = image
        }
        let accessibilityValue = accessibilityValue(for: snapshot)
        if lastAccessibilityValue != accessibilityValue {
            button.setAccessibilityValue(accessibilityValue)
            lastAccessibilityValue = accessibilityValue
        }
    }

    private func menuGlyphSize(for button: NSStatusBarButton) -> CGFloat {
        let availableHeight = button.bounds.height > 0 ? button.bounds.height : 24
        return min(24, max(22, availableHeight - 2))
    }

    private func accessibilityValue(for snapshot: GlyphSnapshot) -> String {
        if let transient = snapshot.transientPresentation {
            let names = transient.entityNames.isEmpty ? "" : "：" + transient.entityNames.joined(separator: "、")
            switch transient.kind {
            case .chargingStarted: return "开始充电"
            case .fullyCharged: return "电池已充满"
            case .chargingPaused: return "已接电源，暂停充电"
            case .unplugged: return "已拔出电源"
            case .bluetoothConnected: return "蓝牙设备已连接\(names)"
            case .bluetoothDisconnected: return "蓝牙设备已断开\(names)"
            case .wifiConnected: return "Wi‑Fi 已连接"
            case .wifiDisconnected: return "Wi‑Fi 已断开"
            }
        }

        let battery = snapshot.batteryPercent.map { "电量 \($0)%" } ?? "电量未知"
        let wifi: String
        switch snapshot.wifiStatus {
        case .connected: wifi = "Wi‑Fi 已连接"
        case .disconnected: wifi = "Wi‑Fi 未连接"
        case .disabled: wifi = "Wi‑Fi 已关闭"
        case .unknown: wifi = "Wi‑Fi 状态未知"
        }
        return "\(battery)，\(wifi)" + (snapshot.powerStatus == .charging ? "，正在充电" : "")
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.transitionProgress
            _ = model.battery
            _ = model.wifi
            _ = model.centerMode
            _ = model.isLowPowerModeEnabled
            _ = model.chargingPulseOpacity
            _ = model.transientPresentation
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.refreshGlyph()
                self.observeModel()
            }
        }
    }
}

@MainActor
final class GlyphImageRenderer {
    private struct CacheKey: Equatable {
        let snapshot: GlyphSnapshot
        let displaySize: CGFloat
        let scale: CGFloat
        let dark: Bool
    }

    private var cacheKey: CacheKey?
    private var cacheImage: NSImage?

    func image(snapshot: GlyphSnapshot, displaySize: CGFloat, scale: CGFloat, dark: Bool) -> NSImage {
        let key = CacheKey(
            snapshot: cacheSnapshot(for: snapshot),
            displaySize: displaySize,
            scale: scale,
            dark: dark
        )
        if cacheKey == key, let cacheImage {
            return cacheImage
        }

        let view = DuoGlyphView(snapshot: key.snapshot, displaySize: displaySize, layout: .menu)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = false
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: displaySize, height: displaySize))
        cacheKey = key
        cacheImage = image
        return image
    }

    private func cacheSnapshot(for snapshot: GlyphSnapshot) -> GlyphSnapshot {
        let pulse = (snapshot.chargingPulseOpacity * 8).rounded() / 8
        let transient = snapshot.transientPresentation.map { presentation in
            TransientPresentation(
                kind: presentation.kind,
                entityNames: presentation.entityNames,
                progress: (presentation.progress * 30).rounded() / 30
            )
        }
        return GlyphSnapshot(
            batteryFraction: snapshot.batteryFraction,
            batteryPercent: snapshot.batteryPercent,
            powerStatus: snapshot.powerStatus,
            batteryAvailability: snapshot.batteryAvailability,
            wifiStatus: snapshot.wifiStatus,
            wifiStrength: snapshot.wifiStrength,
            transitionProgress: snapshot.transitionProgress,
            chargingPulseOpacity: pulse,
            transientPresentation: transient,
            isLowPowerModeEnabled: snapshot.isLowPowerModeEnabled
        )
    }
}
