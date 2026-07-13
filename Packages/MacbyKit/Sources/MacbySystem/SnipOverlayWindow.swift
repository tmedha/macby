import AppKit

public enum SnipSelectionResult {
    case selected(rect: CGRect, screen: NSScreen)
    case cancelled
}

/// Presents one drag-to-select overlay window per connected display and
/// reports the first selection (or cancel) from any of them.
///
/// A single window spanning the union of all screens does NOT work on macOS
/// when "Displays have separate Spaces" is enabled (the default): the window
/// server clips a window to a single display's Space, so a unioned overlay
/// only ever appears on part of a multi-display arrangement. One window per
/// `NSScreen` sidesteps that entirely — each covers exactly its own display.
/// The tradeoff (a drag can't cross a monitor boundary) is immaterial here
/// since a snip is captured from a single display anyway.
@MainActor
public final class SnipOverlayController {
    private var windows: [SnipOverlayWindow] = []
    private var keyMonitor: Any?
    private var completion: ((SnipSelectionResult) -> Void)?
    private var didFinish = false

    public init() {}

    public func begin(screens: [NSScreen], completion: @escaping (SnipSelectionResult) -> Void) {
        self.completion = completion
        // An accessory (menu-bar) app isn't active by default; without this the
        // overlay windows can appear but not reliably receive mouse/key events.
        NSApp.activate(ignoringOtherApps: true)

        for screen in screens {
            let window = SnipOverlayWindow(screen: screen) { [weak self] result in
                self?.finish(result)
            }
            windows.append(window)
            window.begin()
        }

        // Esc routes to whichever overlay is key; a local monitor guarantees it
        // cancels regardless of which display's window currently holds focus.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.finish(.cancelled)
                return nil
            }
            return event
        }
    }

    private func finish(_ result: SnipSelectionResult) {
        guard !didFinish else { return }
        didFinish = true

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil

        for window in windows { window.orderOut(nil) }
        windows.removeAll()

        let completion = self.completion
        self.completion = nil
        completion?(result)
    }
}

/// A borderless, transparent overlay covering exactly one display, used for
/// drag-to-select screen-region capture.
final class SnipOverlayWindow: NSWindow {
    private let overlayView: SnipOverlayView
    private let screenFrame: CGRect

    init(screen: NSScreen, completion: @escaping (SnipSelectionResult) -> Void) {
        screenFrame = screen.frame
        let view = SnipOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        overlayView = view

        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = view

        view.onSelectionComplete = { [screenFrame] rect in
            let globalRect = rect.offsetBy(dx: screenFrame.origin.x, dy: screenFrame.origin.y)
            completion(.selected(rect: globalRect, screen: screen))
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
