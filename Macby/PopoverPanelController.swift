import AppKit
import SwiftUI
import MacbyUI

/// Hosts `PopoverRootView` in a non-activating, borderless floating panel so it
/// can be shown/hidden instantly from the status item or a global hotkey without
/// stealing focus from — or disrupting — the previously frontmost app.
@MainActor
final class PopoverPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var outsideClickMonitor: Any?
    let contentView: () -> PopoverRootView
    /// Whatever app was frontmost right before Macby activated itself to show
    /// the popover — captured here since `NSApp.activate` below makes Macby
    /// the active app, and merely hiding the panel afterward does not restore
    /// whichever app the user was actually in. Pasting needs to reactivate
    /// this app before synthesizing Cmd+V, or the keystroke has nowhere
    /// meaningful to land.
    private(set) var previouslyActiveApp: NSRunningApplication?
    /// Called every time the panel is about to be shown — not just the first
    /// time. The panel/hosting view is created once and reused (shown via
    /// orderFront/orderOut, not recreated), so SwiftUI's `.onAppear` inside
    /// `contentView` only ever fires once for the process's lifetime. Anything
    /// that needs to be current on every open (e.g. re-checking Accessibility
    /// trust, which can change while the popover is closed) has to go here.
    var onWillShow: (() -> Void)?

    init(contentView: @escaping () -> PopoverRootView) {
        self.contentView = contentView
    }

    /// Used for status item clicks — appears anchored to the icon, matching
    /// conventional menu bar app behavior.
    func toggle(relativeTo statusItemButton: NSStatusBarButton?) {
        togglePanel { panel in
            Self.origin(relativeToStatusItem: statusItemButton, panelSize: panel.frame.size)
        }
    }

    /// Used for the global keyboard shortcut — appears near the mouse cursor
    /// rather than jumping to the menu bar corner, since a hotkey can be
    /// triggered from anywhere on screen.
    func toggleNearCursor() {
        togglePanel { panel in
            Self.originNearCursor(panelSize: panel.frame.size)
        }
    }

    func hide() {
        panel?.orderOut(nil)
        removeOutsideClickMonitor()
    }

    private func togglePanel(origin: (NSPanel) -> NSPoint) {
        if let panel, panel.isVisible {
            hide()
        } else {
            show(origin: origin)
        }
    }

    private func show(origin: (NSPanel) -> NSPoint) {
        onWillShow?()
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previouslyActiveApp = NSWorkspace.shared.frontmostApplication
        }
        let panel = makePanelIfNeeded()
        panel.setFrameOrigin(origin(panel))

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installOutsideClickMonitor()
    }

    private static func origin(relativeToStatusItem button: NSStatusBarButton?, panelSize: NSSize) -> NSPoint {
        guard let button, let buttonWindow = button.window else {
            return originNearCursor(panelSize: panelSize)
        }
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let point = NSPoint(x: buttonFrame.midX - panelSize.width / 2, y: buttonFrame.minY - panelSize.height - 4)
        return clampToScreen(point, panelSize: panelSize, near: NSPoint(x: buttonFrame.midX, y: buttonFrame.midY))
    }

    private static func originNearCursor(panelSize: NSSize) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        let point = NSPoint(x: mouseLocation.x - panelSize.width / 2, y: mouseLocation.y - panelSize.height - 12)
        return clampToScreen(point, panelSize: panelSize, near: mouseLocation)
    }

    /// Keeps the panel fully on the screen the reference point (status item or
    /// cursor) is actually on — without this, a hotkey pressed near a screen
    /// edge could position the panel partly or fully off-screen.
    private static func clampToScreen(_ point: NSPoint, panelSize: NSSize, near referencePoint: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(referencePoint) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return point }
        let x = min(max(point.x, visibleFrame.minX), visibleFrame.maxX - panelSize.width)
        let y = min(max(point.y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        return NSPoint(x: x, y: y)
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let hosting = NSHostingView(rootView: contentView())
        // .titled was previously included alongside .borderless (whose raw
        // value is 0, so it contributed nothing to the OptionSet) — .titled
        // alone made AppKit draw its own native title-bar-region corner
        // rounding, independent of and misaligned with the SwiftUI content's
        // own glassEffect RoundedRectangle shape, producing a visible
        // double/mismatched border. A plain [.nonactivatingPanel, .borderless]
        // panel draws no window chrome of its own, so the SwiftUI shape is the
        // only rounded-corner source. NSPanel (unlike plain NSWindow) already
        // defaults canBecomeKeyWindow to true, so this doesn't affect the
        // search field's ability to receive keyboard focus.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        // Required for SwiftUI's glassEffect() (macOS 26+) to actually
        // composite as glass — sampling/refracting what's behind the window —
        // rather than sitting on an opaque backing. Harmless pre-26, where the
        // content view falls back to .regularMaterial instead.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hosting
        panel.delegate = self

        self.panel = panel
        return panel
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }
}
