import AppKit

/// A borderless, transparent window spanning the union of every connected
/// display, used for drag-to-select screen-region capture. AppKit's screen
/// coordinate space is already shared/global across displays, so a single
/// unioned window gives seamless drag-across-monitor-boundary selection for
/// free, avoiding hand-off logic a per-screen window design would need.
final class SnipOverlayWindow: NSWindow {
    enum SelectionResult {
        case selected(rect: CGRect, screen: NSScreen)
        case cancelled
    }

    private let overlayView: SnipOverlayView

    init(screens: [NSScreen], completion: @escaping (SelectionResult) -> Void) {
        let unionFrame = screens.reduce(CGRect.null) { $0.union($1.frame) }
        let view = SnipOverlayView(frame: NSRect(origin: .zero, size: unionFrame.size))
        overlayView = view

        super.init(contentRect: unionFrame, styleMask: [.borderless], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        // .screenSaver is high enough to sit above normal app windows; whether
        // it renders over another app's full-screen Space is unconfirmed and
        // documented as a known possible limitation rather than assumed.
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = view

        view.onSelectionComplete = { rect in
            let globalRect = rect.offsetBy(dx: unionFrame.origin.x, dy: unionFrame.origin.y)
            let screen = screens.first {
                $0.frame.contains(CGPoint(x: globalRect.midX, y: globalRect.midY))
            } ?? screens.first
            if let screen {
                completion(.selected(rect: globalRect, screen: screen))
            } else {
                completion(.cancelled)
            }
        }
        view.onCancel = {
            completion(.cancelled)
        }
    }

    override var canBecomeKey: Bool { true }

    func begin() {
        makeKeyAndOrderFront(nil)
        makeFirstResponder(overlayView)
    }
}

private final class SnipOverlayView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentRect: CGRect?
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .cursorUpdate], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(startPoint.x, point.x),
            y: min(startPoint.y, point.y),
            width: abs(point.x - startPoint.x),
            height: abs(point.y - startPoint.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            startPoint = nil
            currentRect = nil
            needsDisplay = true
        }
        guard let rect = currentRect, rect.width > 2, rect.height > 2 else {
            onCancel?()
            return
        }
        onSelectionComplete?(rect)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        guard let rect = currentRect else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.black.setFill()
        rect.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1
        border.stroke()

        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.6)
        ]
        label.draw(at: CGPoint(x: rect.minX, y: rect.maxY + 4), withAttributes: attrs)
    }
}
