import CoreGraphics
import Foundation

/// Converts a selection rect from AppKit's global screen space (bottom-left
/// origin, points, shared across all displays) into a single display's local
/// pixel space (top-left origin, native resolution) — what ScreenCaptureKit's
/// captured `CGImage` is expressed in. Kept as a pure function, separate from
/// any NSScreen/NSWindow types, so it's cheap to unit test — Y-flip/scale math
/// like this is exactly the kind of thing that silently produces mirrored or
/// off-by-one crops.
enum SnipCoordinateConversion {
    static func pixelRect(
        for selectionRect: CGRect,
        screenFrame: CGRect,
        backingScaleFactor: CGFloat
    ) -> CGRect {
        let local = selectionRect.offsetBy(dx: -screenFrame.origin.x, dy: -screenFrame.origin.y)
        let flipped = CGRect(
            x: local.origin.x,
            y: screenFrame.height - local.origin.y - local.height,
            width: local.width,
            height: local.height
        )
        return flipped.applying(CGAffineTransform(scaleX: backingScaleFactor, y: backingScaleFactor))
    }
}
