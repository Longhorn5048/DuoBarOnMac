import AppKit
import SwiftUI

@MainActor
final class DetailsPanelController {
    private let model: PresentationState
    private let motion: MotionCoordinator
    private let launchAtLogin: LaunchAtLoginService
    private weak var statusButton: NSStatusBarButton?
    private var panel: DetailsPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private(set) var isLaunchAtLogin = false

    init(
        model: PresentationState,
        motion: MotionCoordinator,
        launchAtLogin: LaunchAtLoginService,
        statusButton: NSStatusBarButton
    ) {
        self.model = model
        self.motion = motion
        self.launchAtLogin = launchAtLogin
        self.statusButton = statusButton
        isLaunchAtLogin = launchAtLogin.isEnabled
    }

    func toggle() {
        panel?.isVisible == true ? close() : open()
    }

    func open() {
        if panel == nil {
            makePanel()
        }
        guard let panel else { return }
        position(panel)
        let finalFrame = panel.frame
        var initialFrame = finalFrame
        initialFrame.origin.y += 8
        panel.setFrame(initialFrame, display: false)
        panel.alphaValue = 0
        model.isPanelPresented = true
        panel.orderFrontRegardless()
        panel.makeKey()
        installEventMonitors()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(finalFrame, display: true)
            panel.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        model.isPanelPresented = false
        removeEventMonitors()
        statusButton?.window?.makeFirstResponder(statusButton)
        let currentFrame = panel.frame
        var finalFrame = currentFrame
        finalFrame.origin.y += 8
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(finalFrame, display: false)
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(finalFrame, display: false)
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
        })
    }

    private func makePanel() {
        let panel = DetailsPanel()
        let content = DetailsView(
            model: model,
            isLaunchAtLogin: isLaunchAtLogin,
            onModeChange: { [weak self] mode in
                self?.motion.move(to: mode)
            },
            onLaunchAtLoginChange: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            },
            onEventHintsChange: { [weak self] enabled in
                self?.model.setEventHintsEnabled(enabled)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        panel.contentView = NSHostingView(rootView: content)
        self.panel = panel
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard launchAtLogin.setEnabled(enabled) else { return }
        isLaunchAtLogin = enabled
        // Rebuild the root view so the toggle reflects the result immediately.
        panel?.contentView = NSHostingView(rootView: DetailsView(
            model: model,
            isLaunchAtLogin: isLaunchAtLogin,
            onModeChange: { [weak self] mode in self?.motion.move(to: mode) },
            onLaunchAtLoginChange: { [weak self] value in self?.setLaunchAtLogin(value) },
            onEventHintsChange: { [weak self] value in self?.model.setEventHintsEnabled(value) },
            onQuit: { NSApp.terminate(nil) }
        ))
    }

    private func position(_ panel: NSPanel) {
        guard let buttonWindow = statusButton?.window,
              let statusButton,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }

        let buttonFrame = buttonWindow.convertToScreen(statusButton.frame)
        let size = panel.contentView?.fittingSize ?? NSSize(width: 320, height: 380)
        let visible = screen.visibleFrame
        let x = min(max(buttonFrame.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        let y = max(buttonFrame.minY - size.height - 7, visible.minY + 8)
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false)
    }

    private func installEventMonitors() {
        removeEventMonitors()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                close()
                return nil
            }
            if [.leftMouseDown, .rightMouseDown].contains(event.type),
               let panel,
               !panel.frame.contains(NSEvent.mouseLocation),
               event.window !== statusButton?.window {
                close()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel, panel.isVisible else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                close()
            }
        }
    }

    private func removeEventMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

}

final class DetailsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
