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

    init(contentView: @escaping () -> PopoverRootView) {
        self.contentView = contentView
    }

    func toggle(relativeTo statusItemButton: NSStatusBarButton?) {
        if let panel, panel.isVisible {
            hide()
        } else {
            show(relativeTo: statusItemButton)
        }
    }

    func show(relativeTo statusItemButton: NSStatusBarButton?) {
        let panel = makePanelIfNeeded()

        if let button = statusItemButton, let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.frame)
            let x = buttonFrame.midX - panel.frame.width / 2
            let y = buttonFrame.minY - panel.frame.height - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let x = screen.frame.midX - panel.frame.width / 2
            let y = screen.frame.midY - panel.frame.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installOutsideClickMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        removeOutsideClickMonitor()
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let hosting = NSHostingView(rootView: contentView())
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
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
