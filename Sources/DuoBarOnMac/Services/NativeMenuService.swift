import AppKit
import ApplicationServices
import Observation

/// Delegates privileged system actions to Apple's own menu, without shell authorization.
@MainActor
@Observable
final class NativeMenuService {
    enum Menu: String {
        case battery = "Battery"
        case wifi = "WiFi"

        var identifier: String { "com.apple.menuextra.\(rawValue.lowercased())" }
    }

    private(set) var errorMessage: String?

    func open(_ menu: Menu) {
        errorMessage = nil
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            errorMessage = DuoText.resolve(DuoText.accessibilityPermissionError)
            return
        }
        guard let process = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else {
            errorMessage = DuoText.resolve(DuoText.controlCenterUnavailableError)
            return
        }
        let application = AXUIElementCreateApplication(process.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 1)
        let elements = descendants(application)
        guard let item = elements.first(where: {
            string($0, kAXIdentifierAttribute) == menu.identifier
        }) else {
            // Hidden menu extras are not guaranteed to remain in the AX tree.
            // Do not silently open an unrelated settings page or report success.
            errorMessage = DuoText.resolve(DuoText.nativeMenuUnavailableError)
            return
        }
        let result = AXUIElementPerformAction(item, kAXPressAction as CFString)
        if result != .success {
            errorMessage = DuoText.resolve(LocalizedStringResource(
                "native_menu_open_error",
                defaultValue: "System could not open the native menu (\(result.rawValue))",
                bundle: .module
            ))
        }
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func descendants(_ root: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue = [root]
        // Bound traversal and avoid revisiting the menu bar through multiple attributes.
        while !queue.isEmpty, result.count < 256 {
            let element = queue.removeFirst()
            guard !result.contains(where: { CFEqual($0, element) }) else { continue }
            result.append(element)
            for attribute in [kAXChildrenAttribute, kAXMenuBarAttribute, kAXExtrasMenuBarAttribute] {
                var value: CFTypeRef?
                guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                      let value else { continue }
                if CFGetTypeID(value) == AXUIElementGetTypeID() {
                    queue.append(value as! AXUIElement)
                } else if let children = value as? [AXUIElement] {
                    queue.append(contentsOf: children)
                }
            }
        }
        return result
    }
}
