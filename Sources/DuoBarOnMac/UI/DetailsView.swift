import AppKit
import SwiftUI

struct DetailsView: View {
    let model: PresentationState
    let lowPowerMode: LowPowerModeService
    @State private var nativeMenus = NativeMenuService()
    let isLaunchAtLogin: Bool
    let onModeChange: (CenterMode) -> Void
    let onLaunchAtLoginChange: (Bool) -> Void
    let onEventHintsChange: (Bool) -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            StatusSummarySection(battery: model.battery, wifi: model.wifi, bluetooth: model.bluetooth)
            ChargingDetailsSection(battery: model.battery, onOpenBattery: { nativeMenus.open(.battery) })
            Divider()
            LowPowerSection(service: lowPowerMode, powerStatus: model.battery.powerStatus,
                            onOpenBattery: { nativeMenus.open(.battery) })
            HStack {
                Button("电池菜单…") { nativeMenus.open(.battery) }
                Spacer()
                Button("Wi-Fi 菜单…") { nativeMenus.open(.wifi) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            if let error = nativeMenus.errorMessage {
                Text(verbatim: error).font(.caption).foregroundStyle(.red)
            }
            ModePickerSection(mode: model.centerMode, onModeChange: onModeChange)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            guard model.isPanelPresented else { return }
            Task { await lowPowerMode.refresh() }
        }
    }
}

private struct ChargingDetailsSection: View {
    let battery: BatteryState
    let onOpenBattery: () -> Void

    var body: some View {
        if battery.powerStatus == .connectedPaused {
            HStack {
                Text("充电已暂停").foregroundStyle(.secondary)
                Spacer()
                Button("充电选项…", action: onOpenBattery)
                    .buttonStyle(.plain)
                    .help("打开原生电池菜单查看排程及立即充满选项")
            }
            .font(.system(size: 12))
        } else if battery.isFinishingCharge {
            Text("正在完成充电")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let minutes = battery.minutesToFull {
            Text("约 \(minutes) 分钟充满")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ModePickerSection: View {
    let mode: CenterMode
    let onModeChange: (CenterMode) -> Void

    var body: some View {
        Picker("中心显示", selection: Binding(get: { mode }, set: onModeChange)) {
            ForEach(CenterMode.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

private struct StatusSummarySection: View {
    let battery: BatteryState
    let wifi: WiFiState
    let bluetooth: BluetoothState

    var body: some View {
        VStack(spacing: 12) {
            StatusRow(symbol: battery.powerStatus == .charging ? "battery.100.bolt" : "battery.100", title: "电池", value: batteryValue)
            StatusRow(symbol: "wifi", title: "Wi-Fi", value: wifiValue)
            StatusRow(symbol: "antenna.radiowaves.left.and.right", title: "蓝牙", value: bluetoothValue)
        }
    }

    private var batteryValue: String {
        let value = battery.percent.map { "\($0)%" } ?? "—"
        switch battery.powerStatus {
        case .charging: return "\(value) · 充电中"
        case .connectedPaused: return "\(value) · 暂停充电"
        case .charged: return "\(value) · 已充满"
        default: return value
        }
    }

    private var wifiValue: String {
        switch wifi.status {
        case .connected: return wifi.name ?? "已连接"
        case .disconnected: return "未连接"
        case .disabled: return "已关闭"
        case .unknown: return "—"
        }
    }

    private var bluetoothValue: String {
        guard bluetooth.availability == .available else { return "—" }
        switch bluetooth.connectedCount {
        case 0: return "未连接"
        case 1: return bluetooth.connectedDevices[0].name
        default: return "\(bluetooth.connectedCount) 台设备"
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
                .help(value)
        }
        .font(.system(size: 13))
    }
}

private struct LowPowerSection: View {
    let service: LowPowerModeService
    let powerStatus: PowerStatus
    let onOpenBattery: () -> Void

    private var profile: PowerProfile? {
        switch powerStatus {
        case .onBattery: return .battery
        case .charging, .charged, .connectedPaused: return .adapter
        case .unknown: return nil
        }
    }

    var body: some View {
        HStack {
            Text("低电量模式")
            Spacer()
            Text(profile.flatMap { service.settings[$0] }.map { $0 ? "已开启" : "已关闭" } ?? "—")
                .foregroundStyle(.secondary)
            Button(action: onOpenBattery) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .help("在原生电池菜单中更改能源模式")
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
            Toggle("状态提醒", isOn: Binding(get: { eventHintsEnabled }, set: onEventHintsChange))
            Toggle("登录时启动", isOn: Binding(get: { isLaunchAtLogin }, set: onLaunchAtLoginChange))
            HStack {
                Button("系统图标…", action: openSystemIconSettings)
                    .help("在系统设置中隐藏电池与 Wi-Fi 图标")
                Spacer()
                Button("退出", action: onQuit)
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
