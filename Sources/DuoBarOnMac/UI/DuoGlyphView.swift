import AppKit
import SwiftUI

enum GlyphLayout: Equatable {
    case menu
    case detail
}

private struct GlyphMetrics {
    let ringStroke: CGFloat
    let centerStroke: CGFloat
    let dotDiameter: CGFloat
    let centerScale: CGFloat
    let twoDigitFont: CGFloat
    let threeDigitFont: CGFloat
    let isMenu: Bool

    init(layout: GlyphLayout, displaySize: CGFloat) {
        switch layout {
        case .menu:
            let scale = 24 / displaySize
            ringStroke = 1.9 * scale
            centerStroke = 1.75 * scale
            dotDiameter = 2.6 * scale
            centerScale = 1.06
            twoDigitFont = 9.0 * scale
            threeDigitFont = 8.0 * scale
            isMenu = true
        case .detail:
            ringStroke = 1.8
            centerStroke = 1.65
            dotDiameter = 2.4
            centerScale = 1
            twoDigitFont = 6.1
            threeDigitFont = 5.1
            isMenu = false
        }
    }
}

struct DuoGlyphView: View {
    let snapshot: GlyphSnapshot
    let displaySize: CGFloat
    let layout: GlyphLayout

    private let foreground = Color.primary

    init(snapshot: GlyphSnapshot, displaySize: CGFloat, layout: GlyphLayout = .detail) {
        self.snapshot = snapshot
        self.displaySize = displaySize
        self.layout = layout
    }

    private var metrics: GlyphMetrics {
        GlyphMetrics(layout: layout, displaySize: displaySize)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var body: some View {
        ZStack {
            RingShape(progress: 1)
                .stroke(ringColor.opacity(0.18), style: StrokeStyle(lineWidth: metrics.ringStroke, lineCap: .round))

            RingShape(progress: snapshot.batteryFraction ?? 0)
                .stroke(
                    ringColor.opacity(snapshot.powerStatus == .charging ? snapshot.chargingPulseOpacity : 1),
                    style: StrokeStyle(lineWidth: metrics.ringStroke, lineCap: .round)
                )

            CenterMorphView(snapshot: snapshot, foreground: foreground, metrics: metrics)


        }
        .frame(width: 24, height: 24)
        .scaleEffect(displaySize / 24)
        .frame(width: displaySize, height: displaySize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var ringColor: Color {
        switch snapshot.ringTone {
        case .normal: return foreground
        case .charging: return Color(nsColor: .systemGreen)
        case .critical: return Color(nsColor: .systemRed)
        case .lowPower: return Color(nsColor: .systemYellow)
        }
    }

    private var accessibilityLabel: String {
        if let transient = snapshot.transientPresentation {
            switch transient.kind {
            case .chargingStarted: return "DuoBar，开始充电"
            case .fullyCharged: return "DuoBar，电池已充满"
            case .chargingPaused: return "DuoBar，已接电源，暂停充电"
            case .unplugged: return "DuoBar，已拔出电源"
            case .bluetoothConnected: return "DuoBar，蓝牙设备已连接"
            case .bluetoothDisconnected: return "DuoBar，蓝牙设备已断开"
            case .wifiConnected: return "DuoBar，Wi‑Fi 已连接"
            case .wifiDisconnected: return "DuoBar，Wi‑Fi 已断开"
            }
        }

        let batteryText = snapshot.batteryPercent.map { "电量 \($0)%" } ?? "电量未知"
        switch snapshot.wifiStatus {
        case .connected: return "DuoBar，\(batteryText)，Wi‑Fi 已连接"
        case .disconnected: return "DuoBar，\(batteryText)，Wi‑Fi 未连接"
        case .disabled: return "DuoBar，\(batteryText)，Wi‑Fi 已关闭"
        case .unknown: return "DuoBar，\(batteryText)，Wi‑Fi 未知"
        }
    }
}

private struct RingShape: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 1.2
        let start = 135.0
        let end = start + 270.0 * min(max(progress, 0), 1)
        let sampleCount = max(Int((end - start) / 8), 1)
        var path = Path()

        for index in 0...sampleCount {
            let angle = (start + (end - start) * Double(index) / Double(sampleCount)) * .pi / 180
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private struct CenterMorphView: View {
    let snapshot: GlyphSnapshot
    let foreground: Color
    let metrics: GlyphMetrics

    var body: some View {
        ZStack {
            ZStack {
                if let symbol = snapshot.powerSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(foreground)
                        .offset(y: -1)
                }
                BaseCenterContents(snapshot: snapshot, foreground: foreground, metrics: metrics)
            }
            .opacity(baseOpacity)

            if let transient = snapshot.transientPresentation {
                TransientEventGlyph(presentation: transient, foreground: foreground)
                    .opacity(eventOpacity * eventPulseOpacity)
                    .scaleEffect(eventScale)
            }
        }
        .frame(width: 24, height: 24)
    }

    private var baseOpacity: Double {
        if reduceMotion { return snapshot.transientPresentation == nil ? 1 : 0 }
        guard let presentation = snapshot.transientPresentation else { return 1 }
        let progress = presentation.progress
        if progress < 0.08 { return 1 - progress / 0.08 }
        if progress > 0.84 { return min((progress - 0.84) / 0.16, 1) }
        return 0
    }

    private var eventOpacity: Double {
        if reduceMotion { return snapshot.transientPresentation == nil ? 0 : 1 }
        guard let presentation = snapshot.transientPresentation else { return 0 }
        let progress = presentation.progress
        if progress < 0.08 { return 0 }
        if progress < 0.21 { return min((progress - 0.08) / 0.13, 1) }
        if progress > 0.84 { return max(1 - (progress - 0.84) / 0.16, 0) }
        return 1
    }

    private var eventScale: CGFloat {
        if reduceMotion { return 1 }
        guard let presentation = snapshot.transientPresentation else { return 1 }
        let progress = presentation.progress
        if progress < 0.21 {
            return 0.92 + CGFloat(min(max((progress - 0.08) / 0.13, 0), 1)) * 0.08
        }
        return 1
    }

    private var eventPulseOpacity: Double {
        guard !reduceMotion,
              let presentation = snapshot.transientPresentation,
              presentation.progress >= 0.21,
              presentation.progress <= 0.84 else { return 1 }
        let holdProgress = (presentation.progress - 0.21) / 0.63
        return 0.9 + 0.1 * (0.5 + 0.5 * cos(holdProgress * 2 * .pi))
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

private struct BaseCenterContents: View {
    let snapshot: GlyphSnapshot
    let foreground: Color
    let metrics: GlyphMetrics

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                MorphingSegmentShape(
                    index: index,
                    progress: centerProgress,
                    centerScale: metrics.centerScale
                )
                .stroke(
                    foreground.opacity(wifiOpacity(for: index)),
                    style: StrokeStyle(lineWidth: metrics.centerStroke, lineCap: .round, lineJoin: .round)
                )
            }

            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(foreground.opacity(dotOpacity(for: index)))
                    .frame(width: metrics.dotDiameter, height: metrics.dotDiameter)
                    .position(dotPosition(for: index))
            }

            DisconnectedMark()
                .stroke(foreground, style: StrokeStyle(lineWidth: metrics.centerStroke, lineCap: .round))
                .opacity(disconnectedMarkOpacity)

            if snapshot.wifiStatus == .unknown {
                Text("?")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground)
                    .opacity((1 - centerProgress) * 0.9)
            }

            if snapshot.powerSymbol == nil {
            if snapshot.batteryAvailability == .unavailable {
                Text("—")
                    .font(.system(size: 6.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(foreground)
                    .opacity(snapshot.transitionProgress)
            } else if let percent = snapshot.batteryPercent {
                Text(verbatim: "\(percent)")
                    .font(.system(
                        size: percent == 100 ? metrics.threeDigitFont : metrics.twoDigitFont,
                        weight: .semibold,
                        design: .monospaced
                    ))
                    .foregroundStyle(foreground)
                    .minimumScaleFactor(1)
                    .offset(y: metrics.isMenu ? -0.5 * (24 / 22) : 0)
                    .opacity(snapshot.transitionProgress)
            }
            }
        }
        .frame(width: 24, height: 24)
    }

    private var centerProgress: CGFloat {
        snapshot.powerSymbol == nil ? snapshot.transitionProgress : 1
    }

    private var disconnectedMarkOpacity: Double {
        switch snapshot.wifiStatus {
        case .disconnected, .disabled: return 1 - centerProgress
        default: return 0
        }
    }

    private func wifiOpacity(for index: Int) -> Double {
        let base: Double
        switch snapshot.wifiStatus {
        case .connected:
            guard let strength = snapshot.wifiStrength else { return 0.22 * (1 - centerProgress) }
            // Path order is outer arc, middle arc, inner arc, center point.
            base = index >= 4 - strength ? 1 : 0.2
        case .disconnected, .disabled: base = 0.2
        case .unknown: base = 0.35
        }
        return base * (1 - centerProgress)
    }

    private func dotOpacity(for index: Int) -> Double {
        let base: Double
        switch snapshot.wifiStatus {
        case .connected:
            guard let strength = snapshot.wifiStrength else { base = 0.22; return base * centerProgress }
            base = index < strength ? 1 : 0.22
        case .disconnected, .disabled: base = 0.2
        case .unknown: base = 0.35
        }
        return base * centerProgress
    }

    private func dotPosition(for index: Int) -> CGPoint {
        CGPoint(x: [6.9, 10.3, 13.7, 17.1][index], y: 19.1)
    }
}

private struct TransientEventGlyph: View {
    let presentation: TransientPresentation
    let foreground: Color

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(foreground)
    }

    private var symbolName: String {
        switch presentation.kind {
        case .chargingStarted: return "bolt.fill"
        case .fullyCharged: return "checkmark.circle.fill"
        case .chargingPaused: return "powerplug.fill"
        case .unplugged: return "battery.100"
        case .bluetoothConnected: return "antenna.radiowaves.left.and.right"
        case .bluetoothDisconnected: return "antenna.radiowaves.left.and.right.slash"
        case .wifiConnected: return "wifi"
        case .wifiDisconnected: return "wifi.slash"
        }
    }
}

private struct MorphingSegmentShape: Shape {
    let index: Int
    var progress: CGFloat
    let centerScale: CGFloat

    func path(in rect: CGRect) -> Path {
        let wifiPoints: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: 6.5, y: 9), CGPoint(x: 12, y: 4.7), CGPoint(x: 17.5, y: 9)),
            (CGPoint(x: 8.3, y: 11.7), CGPoint(x: 12, y: 8.7), CGPoint(x: 15.7, y: 11.7)),
            (CGPoint(x: 10.1, y: 14.1), CGPoint(x: 12, y: 12.5), CGPoint(x: 13.9, y: 14.1)),
            (CGPoint(x: 11.99, y: 16), CGPoint(x: 12, y: 16), CGPoint(x: 12.01, y: 16))
        ]
        let target = CGPoint(x: [6.9, 10.3, 13.7, 17.1][index], y: 19.1)
        let source = wifiPoints[index]
        let p = min(max(progress, 0), 1)
        let start = source.0.interpolated(to: target, amount: p).scaledAroundCenter(by: centerScale)
        let control = source.1.interpolated(to: target, amount: p).scaledAroundCenter(by: centerScale)
        let end = source.2.interpolated(to: target, amount: p).scaledAroundCenter(by: centerScale)

        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

private struct DisconnectedMark: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        path.move(to: CGPoint(x: 8.3 * scale, y: 8.4 * scale))
        path.addLine(to: CGPoint(x: 15.8 * scale, y: 15.9 * scale))
        path.move(to: CGPoint(x: 15.7 * scale, y: 8.5 * scale))
        path.addLine(to: CGPoint(x: 8.4 * scale, y: 15.8 * scale))
        return path
    }
}

private extension CGPoint {
    func interpolated(to other: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (other.x - x) * amount,
            y: y + (other.y - y) * amount
        )
    }

    func scaledAroundCenter(by scale: CGFloat) -> CGPoint {
        CGPoint(x: 12 + (x - 12) * scale, y: 12 + (y - 12) * scale)
    }
}
