import AppKit

/// Shared by `PasteboardMonitor` (captured copies) and `SnipCaptureService`
/// (screen-region captures) so both go through the same PNG/thumbnail logic.
extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    func thumbnailPNGData(maxDimension: CGFloat) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1)
        thumbnail.unlockFocus()
        return thumbnail.pngData()
    }
}
