import CoreGraphics
import Testing
@testable import MacbySystem

@Suite struct SnipCoordinateConversionTests {
    @Test func fullScreenSelectionMapsToFullNativeResolution() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let result = SnipCoordinateConversion.pixelRect(
            for: screenFrame, screenFrame: screenFrame, backingScaleFactor: 2
        )
        #expect(result == CGRect(x: 0, y: 0, width: 2000, height: 1600))
    }

    @Test func selectionNearTopOfAppKitSpaceMapsNearTopOfPixelImage() {
        // AppKit's screen space is bottom-left origin, y increasing upward;
        // CGImage pixel space is top-left origin. A selection near the top of
        // the screen (high y, close to screenFrame.height) must land near y=0
        // in the pixel rect, not near the bottom.
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let selection = CGRect(x: 100, y: 700, width: 50, height: 50)
        let result = SnipCoordinateConversion.pixelRect(
            for: selection, screenFrame: screenFrame, backingScaleFactor: 2
        )
        #expect(result == CGRect(x: 200, y: 100, width: 100, height: 100))
    }

    @Test func nonOriginScreenFrameIsNormalizedBeforeFlipping() {
        // A secondary display positioned to the left of the primary has a
        // negative-x screenFrame origin; the selection must be normalized
        // relative to that origin before the Y-flip, not treated as global.
        let screenFrame = CGRect(x: -1000, y: 0, width: 1000, height: 800)
        let selection = CGRect(x: -900, y: 700, width: 50, height: 50)
        let result = SnipCoordinateConversion.pixelRect(
            for: selection, screenFrame: screenFrame, backingScaleFactor: 1
        )
        #expect(result == CGRect(x: 100, y: 50, width: 50, height: 50))
    }
}
