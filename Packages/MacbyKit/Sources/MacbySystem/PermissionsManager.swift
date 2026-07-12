import AppKit
import ApplicationServices
import Foundation

@MainActor
public final class PermissionsManager: ObservableObject {
    @Published public private(set) var isAccessibilityTrusted: Bool

    public init() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    /// Prompts the system Accessibility permission dialog if not already granted.
    @discardableResult
    public func requestAccessibilityIfNeeded() -> Bool {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        isAccessibilityTrusted = trusted
        return trusted
    }

    public func refresh() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    public func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
