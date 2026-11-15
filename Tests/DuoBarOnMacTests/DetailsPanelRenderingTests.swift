import AppKit
import QuartzCore
import SwiftUI
import XCTest
@testable import DuoBarOnMac

@MainActor
final class DetailsPanelRenderingTests: XCTestCase {
    func testNativeSurfaceCannotPaintTheMenusSquareCornersAfterResizing() throws {
        let view = DetailsHostingView(rootView: Color.clear)
        let layer = try XCTUnwrap(view.layer)
        // Stand in for a native material surface that fills the hosting bounds.
        let surface = CALayer()
        surface.backgroundColor = NSColor.red.cgColor
        layer.addSublayer(surface)

        for height in [240, 380] {
            view.setFrameSize(NSSize(width: 280, height: height))
            view.layoutSubtreeIfNeeded()
            surface.frame = view.bounds
            let context = try XCTUnwrap(CGContext(
                data: nil, width: 280, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            layer.render(in: context)
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))

            for (x, y) in [(0, 0), (279, 0), (0, height - 1), (279, height - 1)] {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y))
                XCTAssertEqual(color.alphaComponent, 0, accuracy: 0.01, "Menu corners must stay transparent")
            }
            let center = try XCTUnwrap(bitmap.colorAt(x: 140, y: height / 2))
            XCTAssertEqual(center.alphaComponent, 1, accuracy: 0.01, "Clipping must preserve the menu surface")
            let edge = try XCTUnwrap(bitmap.colorAt(x: 0, y: height / 2))
            XCTAssertEqual(edge.alphaComponent, 1, accuracy: 0.01, "Straight edges must remain intact")
        }
    }
}
