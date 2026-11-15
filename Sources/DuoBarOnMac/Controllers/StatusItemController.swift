import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: PresentationState
    private let motion: MotionCoordinator
    private let wifiProvider: WiFiProvider
    private let statusItem = NSStatusBar.system.statusItem(withLength: 28)
    private let imageRenderer = GlyphImageRenderer()
    private var lastAccessibilityValue: String?
    private var appearanceObservation: NSKeyValueObservation?
    private var panelController: DetailsPanelController?

    init(model: PresentationState, motion: MotionCoordinator, wifiProvider: WiFiProvider) {
        self.model = model
        self.motion = motion
        self.wifiProvider = wifiProvider
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
        button.setAccessibilityLabel(DuoText.resolve(DuoText.statusItemLabel))
        panelController = DetailsPanelController(
            model: model,
            motion: motion,
            launchAtLogin: LaunchAtLoginService(),
            statusButton: button,
            wifiProvider: wifiProvider
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
            displaySize: Self.menuGlyphSize,
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

    // Match the system status icons instead of stretching with the menu bar height.
    static let menuGlyphSize: CGFloat = 18

    private func accessibilityValue(for snapshot: GlyphSnapshot) -> String {
        DuoText.statusItemAccessibility(snapshot)
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
            _ = model.wifiColorEnabled
            _ = model.wifiDotCount
            _ = model.chargingColorEnabled
            _ = model.batteryColorEnabled
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
            wifiColorEnabled: snapshot.wifiColorEnabled,
            wifiDotCount: snapshot.wifiDotCount,
            chargingColorEnabled: snapshot.chargingColorEnabled,
            batteryColorEnabled: snapshot.batteryColorEnabled,
            transitionProgress: snapshot.transitionProgress,
            chargingPulseOpacity: pulse,
            transientPresentation: transient,
            isLowPowerModeEnabled: snapshot.isLowPowerModeEnabled
        )
    }
}
