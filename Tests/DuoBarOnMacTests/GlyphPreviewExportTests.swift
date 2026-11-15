import XCTest
import AppKit
@testable import DuoBarOnMac

@MainActor
final class GlyphPreviewExportTests: XCTestCase {
    func testExportV012ComparisonImagesWhenRequested() throws {
        guard let outputDirectory = ProcessInfo.processInfo.environment["DUOBAR_PREVIEW_DIR"] else {
            throw XCTSkip("Set DUOBAR_PREVIEW_DIR to export the offline comparison images.")
        }

        let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try exportRingComparison(to: directory.appendingPathComponent("duobar-v0.1.2-ring-calibration.png"))
        try exportWiFiDotComparison(to: directory.appendingPathComponent("duobar-v0.1.2-wifi-dots.png"))
        try exportMenuContents(to: directory.appendingPathComponent("duobar-menu-18pt.png"))
    }

    private func exportMenuContents(to url: URL) throws {
        let bitmap = makeBitmap(width: 640, height: 240)
        let model = PresentationState()
        model.wifi = WiFiState(status: .connected, rssi: -50)
        let renderer = GlyphImageRenderer()
        withContext(bitmap) { context in
            for (row, dark) in [false, true].enumerated() {
                let y = row * 120
                fill(NSRect(x: 0, y: y, width: 640, height: 120), color: dark ? .darkGray : .white)
                for (column, percent) in [5, 50, 80, 100].enumerated() {
                    model.battery = BatteryState(availability: .available, percent: percent, powerStatus: .onBattery)
                    model.transitionProgress = 1
                    let image = renderer.image(snapshot: model.glyphSnapshot, displaySize: 18, scale: 2, dark: dark)
                    draw(image, in: NSRect(x: column * 160 + 44, y: y + 24, width: 72, height: 72), context: context)
                }
            }
        }
        try writePNG(bitmap, to: url)
    }

    private func exportRingComparison(to url: URL) throws {
        let sizes: [(CGFloat, CGFloat, Bool, String)] = [
            (18, 1, false, "18 pt · 1× · light"),
            (18, 2, false, "18 pt · 2× · light"),
            (22, 1, false, "22 pt · 1× · light"),
            (22, 2, false, "22 pt · 2× · light"),
            (24, 1, false, "24 pt · 1× · light"),
            (24, 2, false, "24 pt · 2× · light"),
            (18, 1, true, "18 pt · 1× · dark"),
            (18, 2, true, "18 pt · 2× · dark"),
            (22, 1, true, "22 pt · 1× · dark"),
            (22, 2, true, "22 pt · 2× · dark"),
            (24, 1, true, "24 pt · 1× · dark"),
            (24, 2, true, "24 pt · 2× · dark")
        ]
        let levels: [(Int?, String)] = [
            (0, "0% · 0°"),
            (20, "20% · 54°"),
            (40, "40% · 108°"),
            (50, "50% · 135°"),
            (100, "100% · 270°"),
            (nil, "Unknown")
        ]
        let cellWidth = 142
        let cellHeight = 124
        let headerHeight = 42
        let bitmap = makeBitmap(width: cellWidth * sizes.count, height: headerHeight + cellHeight * levels.count)

        withContext(bitmap) { context in
            fill(NSRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh), color: .white)
            for (column, variant) in sizes.enumerated() {
                let x = column * cellWidth
                drawText(variant.3, at: CGPoint(x: x + 5, y: bitmap.pixelsHigh - 28), color: .black, size: 10)
            }

            let renderer = GlyphImageRenderer()
            for (row, level) in levels.enumerated() {
                let y = bitmap.pixelsHigh - headerHeight - (row + 1) * cellHeight
                for (column, variant) in sizes.enumerated() {
                    let x = column * cellWidth
                    let background = variant.2 ? NSColor(calibratedWhite: 0.16, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)
                    let labelColor = variant.2 ? NSColor.white : NSColor.black
                    fill(NSRect(x: x, y: y, width: cellWidth, height: cellHeight), color: background)
                    let snapshot = snapshot(percent: level.0, wifiStatus: .unknown, wifiStrength: nil, dotCount: .four)
                    let image = renderer.image(snapshot: snapshot, displaySize: variant.0, scale: variant.1, dark: variant.2)
                    let magnifiedSize = variant.0 * 3.5
                    let target = NSRect(
                        x: CGFloat(x) + (CGFloat(cellWidth) - magnifiedSize) / 2,
                        y: CGFloat(y) + 25 + (CGFloat(cellHeight - 25) - magnifiedSize) / 2,
                        width: magnifiedSize,
                        height: magnifiedSize
                    )
                    draw(image, in: target, context: context)
                    drawText(level.1, at: CGPoint(x: x + 8, y: y + 7), color: labelColor, size: 10)
                }
            }
        }

        try writePNG(bitmap, to: url)
    }

    private func exportWiFiDotComparison(to url: URL) throws {
        let cases: [(WiFiDotCount, Int, String)] = [
            (.three, 4, "3 dots · −50 dBm"),
            (.three, 3, "3 dots · −60 dBm"),
            (.three, 2, "3 dots · −70 dBm"),
            (.three, 1, "3 dots · −80 dBm"),
            (.four, 4, "4 dots · −50 dBm"),
            (.four, 3, "4 dots · −60 dBm"),
            (.four, 2, "4 dots · −70 dBm"),
            (.four, 1, "4 dots · −80 dBm")
        ]
        let cellWidth = 132
        let cellHeight = 124
        let headerHeight = 36
        let variants: [(CGFloat, CGFloat, Bool, String)] = [
            (18, 1, false, "Light · 18 pt · 1×"),
            (18, 2, false, "Light · 18 pt · 2×"),
            (22, 1, false, "Light · 22 pt · 1×"),
            (22, 2, false, "Light · 22 pt · 2×"),
            (24, 1, false, "Light · 24 pt · 1×"),
            (24, 2, false, "Light · 24 pt · 2×"),
            (18, 1, true, "Dark · 18 pt · 1×"),
            (18, 2, true, "Dark · 18 pt · 2×"),
            (22, 1, true, "Dark · 22 pt · 1×"),
            (22, 2, true, "Dark · 22 pt · 2×"),
            (24, 1, true, "Dark · 24 pt · 1×"),
            (24, 2, true, "Dark · 24 pt · 2×")
        ]
        let bitmap = makeBitmap(width: cellWidth * cases.count, height: headerHeight + cellHeight * variants.count)

        withContext(bitmap) { context in
            fill(NSRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh), color: .white)
            for (column, item) in cases.enumerated() {
                drawText(item.2, at: CGPoint(x: column * cellWidth + 4, y: bitmap.pixelsHigh - 25), color: .black, size: 9)
            }

            let renderer = GlyphImageRenderer()
            for (row, variant) in variants.enumerated() {
                let dark = variant.2
                let y = bitmap.pixelsHigh - headerHeight - (row + 1) * cellHeight
                for (column, item) in cases.enumerated() {
                    let x = column * cellWidth
                    let background = dark ? NSColor(calibratedWhite: 0.16, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)
                    let labelColor = dark ? NSColor.white : NSColor.black
                    fill(NSRect(x: x, y: y, width: cellWidth, height: cellHeight), color: background)
                    let snapshot = snapshot(percent: 82, wifiStatus: .connected, wifiStrength: item.1, dotCount: item.0)
                    let image = renderer.image(snapshot: snapshot, displaySize: variant.0, scale: variant.1, dark: dark)
                    let magnifiedSize = variant.0 * 3.5
                    let target = NSRect(
                        x: CGFloat(x) + (CGFloat(cellWidth) - magnifiedSize) / 2,
                        y: CGFloat(y) + 23 + (CGFloat(cellHeight - 23) - magnifiedSize) / 2,
                        width: magnifiedSize,
                        height: magnifiedSize
                    )
                    draw(image, in: target, context: context)
                    drawText(variant.3, at: CGPoint(x: x + 5, y: y + 7), color: labelColor, size: 8)
                }
            }
        }

        try writePNG(bitmap, to: url)
    }

    private func snapshot(
        percent: Int?,
        wifiStatus: WiFiStatus,
        wifiStrength: Int?,
        dotCount: WiFiDotCount
    ) -> GlyphSnapshot {
        GlyphSnapshot(
            batteryFraction: percent.map { Double($0) / 100 },
            batteryPercent: nil,
            powerStatus: .onBattery,
            batteryAvailability: percent == nil ? .unknown : .available,
            wifiStatus: wifiStatus,
            wifiStrength: wifiStrength,
            wifiColorEnabled: true,
            wifiDotCount: dotCount,
            chargingColorEnabled: true,
            batteryColorEnabled: true,
            transitionProgress: 1,
            chargingPulseOpacity: 1,
            transientPresentation: nil,
            isLowPowerModeEnabled: false
        )
    }

    private func makeBitmap(width: Int, height: Int) -> NSBitmapImageRep {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
    }

    private func withContext(_ bitmap: NSBitmapImageRep, draw body: (NSGraphicsContext) -> Void) {
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .none
        body(context)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func fill(_ rect: NSRect, color: NSColor) {
        color.setFill()
        rect.fill()
    }

    private func drawText(_ text: String, at point: CGPoint, color: NSColor, size: CGFloat) {
        (text as NSString).draw(
            at: point,
            withAttributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color]
        )
    }

    private func draw(_ image: NSImage, in rect: NSRect, context: NSGraphicsContext) {
        var proposed = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposed, context: context, hints: nil) else { return }
        context.cgContext.draw(cgImage, in: rect)
    }

    private func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "GlyphPreviewExportTests", code: 1)
        }
        try data.write(to: url)
    }
}
