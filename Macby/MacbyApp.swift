import SwiftUI

@main
struct MacbyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Macby is a menu-bar-only (LSUIElement) app — the status item, popover
        // panel, and settings window are all managed imperatively by AppDelegate.
        // This Settings scene exists only so SwiftUI has a Scene to run.
        Settings {
            EmptyView()
        }
    }
}
