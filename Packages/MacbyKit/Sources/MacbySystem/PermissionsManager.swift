import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
public final class PermissionsManager: ObservableObject {
    @Published public private(set) var isAccessibilityTrusted: Bool
    @Published public private(set) var isScreenRecordingTrusted: Bool

    public init() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        isScreenRecordingTrusted = CGPreflightScreenCaptureAccess()
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
        isScreenRecordingTrusted = CGPreflightScreenCaptureAccess()
    }

    public func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Prompts the system Screen Recording permission dialog if not already
    /// granted. Note: unlike Accessibility, a freshly granted decision here
    /// typically only takes effect after Macby is relaunched — TCC caches this
    /// bucket's decision at process start. Callers should tell the user to
    /// relaunch rather than silently retrying capture in-process.
    @discardableResult
    public func requestScreenRecordingIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            isScreenRecordingTrusted = true
            return true
        }
        let granted = CGRequestScreenCaptureAccess()
        isScreenRecordingTrusted = granted
        return granted
    }

    public func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
