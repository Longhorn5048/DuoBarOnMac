import AppKit
import SwiftUI

struct DetailsView: View {
    static let cornerRadius: CGFloat = 16

    let model: PresentationState
    let isLaunchAtLogin: Bool
    let onModeChange: (CenterMode) -> Void
    let onLaunchAtLoginChange: (Bool) -> Void
    let onEventHintsChange: (Bool) -> Void
    let onRequestWiFiName: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            StatusSummarySection(
                battery: model.battery, wifi: model.wifi, bluetooth: model.bluetooth,
                onRequestWiFiName: onRequestWiFiName
            )
            ModePickerSection(mode: model.centerMode, onModeChange: onModeChange)
            AppearanceSection(model: model)
            Divider()
            SettingsSection(
                isLaunchAtLogin: isLaunchAtLogin,
                onLaunchAtLoginChange: onLaunchAtLoginChange,
                eventHintsEnabled: model.eventHintsEnabled,
                onEventHintsChange: onEventHintsChange,
                onQuit: onQuit
            )
        }
        .padding(16)
        .frame(width: 280)
        .modifier(DetailsSurface())
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

private struct DetailsSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: DetailsView.cornerRadius, style: .continuous))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: DetailsView.cornerRadius, style: .continuous))
        }
    }
}

private struct ModePickerSection: View {
    let mode: CenterMode
    let onModeChange: (CenterMode) -> Void

    var body: some View {
        Picker(DuoText.centerDisplay, selection: Binding(get: { mode }, set: onModeChange)) {
            ForEach(CenterMode.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

private struct AppearanceSection: View {
    @Bindable var model: PresentationState
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(DuoText.appearance, isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(DuoText.wifiSignalDots)
                    Spacer(minLength: 8)
                    Picker(DuoText.wifiSignalDots, selection: $model.wifiDotCount) {
                        Text(verbatim: "3").tag(WiFiDotCount.three)
                        Text(verbatim: "4").tag(WiFiDotCount.four)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 76)
                    .accessibilityLabel(Text(DuoText.wifiSignalDots))
                }
                Toggle(DuoText.chargingColor, isOn: $model.chargingColorEnabled)
                Toggle(DuoText.batteryColor, isOn: $model.batteryColorEnabled)
                Toggle(DuoText.wifiSignalColor, isOn: $model.wifiColorEnabled)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.system(size: 13))
    }
}

private struct StatusSummarySection: View {
    let battery: BatteryState
    let wifi: WiFiState
    let bluetooth: BluetoothState
    let onRequestWiFiName: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            StatusRow(symbol: battery.powerStatus == .charging ? "battery.100.bolt" : "battery.100", title: DuoText.battery, value: batteryValue)
            if wifi.status == .connected, wifi.name == nil, wifi.nameAccess != .allowed {
                HStack(spacing: 9) {
                    Image(systemName: "wifi").frame(width: 18).foregroundStyle(.secondary)
                    Text(DuoText.wifi)
                    Spacer(minLength: 8)
                    Button(
                        wifi.nameAccess == .notRequested ? DuoText.showWiFiName : DuoText.allowLocation,
                        action: onRequestWiFiName
                    )
                    .buttonStyle(.link)
                    .help(Text(DuoText.wifiNamePermissionHelp))
                }
                .font(.system(size: 13))
            } else {
                StatusRow(symbol: "wifi", title: DuoText.wifi, value: wifiValue)
            }
            StatusRow(symbol: "antenna.radiowaves.left.and.right", title: DuoText.bluetooth, value: bluetoothValue)
        }
    }

    private var batteryValue: String {
        DuoText.batteryValue(percent: battery.percent, status: battery.powerStatus)
    }

    private var wifiValue: String {
        switch wifi.status {
        case .connected: return wifi.name ?? DuoText.resolve(DuoText.connected)
        case .disconnected: return DuoText.resolve(DuoText.notConnected)
        case .disabled: return DuoText.resolve(DuoText.off)
        case .unknown: return DuoText.resolve(DuoText.unknown)
        }
    }

    private var bluetoothValue: String {
        guard bluetooth.availability == .available else { return DuoText.resolve(DuoText.unknown) }
        switch bluetooth.connectedCount {
        case 0: return DuoText.resolve(DuoText.notConnected)
        case 1: return bluetooth.connectedDevices[0].name
        default: return DuoText.bluetoothDevices(count: bluetooth.connectedCount)
        }
    }
}

private struct StatusRow: View {
    let symbol: String
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).frame(width: 18).foregroundStyle(.secondary)
            Text(title)
            Spacer(minLength: 8)
            Text(verbatim: value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(Text(verbatim: value))
        }
        .font(.system(size: 13))
    }
}

private struct SettingsSection: View {
    let isLaunchAtLogin: Bool
    let onLaunchAtLoginChange: (Bool) -> Void
    let eventHintsEnabled: Bool
    let onEventHintsChange: (Bool) -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Toggle(DuoText.statusHints, isOn: Binding(get: { eventHintsEnabled }, set: onEventHintsChange))
            Toggle(DuoText.launchAtLogin, isOn: Binding(get: { isLaunchAtLogin }, set: onLaunchAtLoginChange))
            HStack {
                Button(DuoText.systemIcons, action: openSystemIconSettings)
                    .help(Text(DuoText.systemIconsHelp))
                Spacer()
                Button(DuoText.quit, action: onQuit)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.system(size: 13))
    }

    private func openSystemIconSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}
