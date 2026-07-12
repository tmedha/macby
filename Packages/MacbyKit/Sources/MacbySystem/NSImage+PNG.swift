import AppKit

/// Shared by `PasteboardMonitor` (captured copies) and `SnipCaptureService`
/// (screen-region captures) so both go through the same PNG/thumbnail logic.
extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // Renders into an explicit NSBitmapImageRep at exact pixel dimensions,
    // rather than NSImage.lockFocus() — lockFocus() captures at the current
    // screen's backing scale factor (2x on Retina), which would silently
    // double the intended maxDimension cap on any Retina-connected build.
    func thumbnailPNGData(maxDimension: CGFloat) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let pxWidth = max(1, Int(size.width * scale))
        let pxHeight = max(1, Int(size.height * scale))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxWidth,
            pixelsHigh: pxHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: pxWidth, height: pxHeight)

        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(
            in: NSRect(x: 0, y: 0, width: CGFloat(pxWidth), height: CGFloat(pxHeight)),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}
