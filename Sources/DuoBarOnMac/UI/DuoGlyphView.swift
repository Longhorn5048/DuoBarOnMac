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
                .stroke(foreground.opacity(0.1), style: StrokeStyle(lineWidth: metrics.ringStroke, lineCap: .butt))

            RingShape(progress: snapshot.batteryFraction ?? 0)
                .stroke(
                    ringColor.opacity(snapshot.powerStatus == .charging ? snapshot.chargingPulseOpacity : 1),
                    style: StrokeStyle(lineWidth: metrics.ringStroke, lineCap: .butt)
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
        DuoText.glyphAccessibility(snapshot)
    }
}

struct BatteryRingGeometry {
    static let startDegrees = 135.0
    static let trackDegrees = 270.0

    static func clampedProgress(_ progress: Double) -> Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    static func sweepDegrees(for progress: Double) -> Double {
        trackDegrees * clampedProgress(progress)
    }

}

struct RingShape: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        let progress = BatteryRingGeometry.clampedProgress(progress)
        guard progress > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 1.2
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(BatteryRingGeometry.startDegrees),
            endAngle: .degrees(BatteryRingGeometry.startDegrees + BatteryRingGeometry.sweepDegrees(for: progress)),
            clockwise: false
        )
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                MorphingSegmentShape(
                    index: index,
                    progress: centerProgress,
                    centerScale: metrics.centerScale,
                    dotCount: snapshot.wifiDotCount
                )
                .stroke(
                    wifiArcColor(for: index).opacity(wifiOpacity(for: index)),
                    style: StrokeStyle(lineWidth: metrics.centerStroke, lineCap: .round, lineJoin: .round)
                )
            }

            ForEach(0..<snapshot.wifiDotCount.rawValue, id: \.self) { index in
                Circle()
                    .fill(wifiDotColor(for: index).opacity(dotOpacity(for: index)))
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

    private func wifiArcColor(for index: Int) -> Color {
        guard snapshot.wifiColorEnabled,
              snapshot.wifiStatus == .connected,
              let strength = snapshot.displayedWiFiStrength else { return foreground }
        let signalSegmentCount = snapshot.wifiDotCount == .three ? 3 : 4
        guard index < signalSegmentCount,
              index >= signalSegmentCount - strength else { return foreground }
        return WiFiSignalPalette.color(
            for: snapshot.wifiDotCount.colorTier(for: strength),
            dark: colorScheme == .dark
        )
    }

    private func wifiDotColor(for index: Int) -> Color {
        guard snapshot.wifiColorEnabled,
              snapshot.wifiStatus == .connected,
              let strength = snapshot.displayedWiFiStrength,
              index < strength else { return foreground }
        return WiFiSignalPalette.color(
            for: snapshot.wifiDotCount.colorTier(for: strength),
            dark: colorScheme == .dark
        )
    }

    private func wifiOpacity(for index: Int) -> Double {
        let base: Double
        switch snapshot.wifiStatus {
        case .connected:
            if snapshot.wifiDotCount == .three && index == 3 {
                base = 0.72
            } else if let strength = snapshot.displayedWiFiStrength {
                let segmentCount = snapshot.wifiDotCount.rawValue
                base = index >= segmentCount - strength ? 1 : 0.2
            } else {
                base = 0.22
            }
        case .disconnected, .disabled: base = 0.2
        case .unknown: base = 0.35
        }
        return base * (1 - centerProgress)
    }

    private func dotOpacity(for index: Int) -> Double {
        let base: Double
        switch snapshot.wifiStatus {
        case .connected:
            guard let strength = snapshot.displayedWiFiStrength else { base = 0.22; return base * centerProgress }
            base = index < strength ? 1 : 0.22
        case .disconnected, .disabled: base = 0.2
        case .unknown: base = 0.35
        }
        return base * centerProgress
    }

    private func dotPosition(for index: Int) -> CGPoint {
        WiFiDotLayout.position(index: index, count: snapshot.wifiDotCount)
    }
}

private enum WiFiDotLayout {
    static func position(index: Int, count: WiFiDotCount) -> CGPoint {
        let positions: [CGFloat] = count == .three ? [8, 12, 16] : [6.9, 10.3, 13.7, 17.1]
        return CGPoint(x: positions[index], y: 19.1)
    }
}

private enum WiFiSignalPalette {
    static func color(for strength: Int, dark: Bool) -> Color {
        switch (strength, dark) {
        case (4, false): return Color(red: 0.078, green: 0.435, blue: 0.216)
        case (3, false): return Color(red: 0.369, green: 0.420, blue: 0.043)
        case (2, false): return Color(red: 0.667, green: 0.306, blue: 0.000)
        case (1, false): return Color(red: 0.675, green: 0.149, blue: 0.133)
        case (4, true): return Color(red: 0.294, green: 0.843, blue: 0.490)
        case (3, true): return Color(red: 0.792, green: 0.847, blue: 0.333)
        case (2, true): return Color(red: 1.000, green: 0.659, blue: 0.329)
        case (1, true): return Color(red: 1.000, green: 0.412, blue: 0.380)
        default: return Color.primary
        }
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
    let dotCount: WiFiDotCount

    func path(in rect: CGRect) -> Path {
        let wifiPoints: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: 6.5, y: 9), CGPoint(x: 12, y: 4.7), CGPoint(x: 17.5, y: 9)),
            (CGPoint(x: 8.3, y: 11.7), CGPoint(x: 12, y: 8.7), CGPoint(x: 15.7, y: 11.7)),
            (CGPoint(x: 10.1, y: 14.1), CGPoint(x: 12, y: 12.5), CGPoint(x: 13.9, y: 14.1)),
            (CGPoint(x: 11.99, y: 16), CGPoint(x: 12, y: 16), CGPoint(x: 12.01, y: 16))
        ]
        let source = wifiPoints[index]
        let target = index < dotCount.rawValue
            ? WiFiDotLayout.position(index: index, count: dotCount)
            : CGPoint(x: 12, y: 19.1)
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
