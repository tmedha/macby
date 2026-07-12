import AppKit
import Foundation
import MacbyCore
import MacbyPersistence

/// Wipes a detected one-time-passcode off the system pasteboard after it's
/// been used, via one or both of two heuristic triggers (both best-effort —
/// macOS gives no API to know definitively "the target app just read the
/// pasteboard during a paste"):
///
/// - `.onPasteDetected`: observes a global Cmd+V via `HotkeyManager`,
///   registered *non-consuming* so the real paste is never blocked. Clearing
///   happens after a short delay, not synchronously in the tap callback —
///   the callback fires before the OS has delivered the key event to the
///   frontmost app, so clearing immediately would risk wiping the pasteboard
///   before that app has actually read it.
/// - `.timeout`: schedules a clear a fixed number of seconds after capture,
///   regardless of whether a paste was observed.
///
/// Either path only clears if the *current* pasteboard content still matches
/// the OTP item in question — if the user copied something else in the
/// meantime, there's nothing to protect and clearing would wipe unrelated data.
@MainActor
public final class OTPAutoClearService {
    private let historyStore: HistoryStore
    private let hotkeyManager: HotkeyManager

    private var enabled = false
    private var trigger: OTPClearTrigger = .both
    private var timeoutSeconds = 30

    private var cmdVToken: HotkeyManager.Token?
    private var pendingTimeoutTasks: [String: Task<Void, Never>] = [:]

    private static let pasteSettleDelayNanoseconds: UInt64 = 300_000_000

    public init(historyStore: HistoryStore, hotkeyManager: HotkeyManager) {
        self.historyStore = historyStore
        self.hotkeyManager = hotkeyManager
    }

    public func updateSettings(enabled: Bool, trigger: OTPClearTrigger, timeoutSeconds: Int) {
        self.enabled = enabled
        self.trigger = trigger
        self.timeoutSeconds = timeoutSeconds

        if enabled && (trigger == .onPasteDetected || trigger == .both) {
            startObservingGlobalPaste()
        } else {
            stopObservingGlobalPaste()
        }

        if !enabled {
            for task in pendingTimeoutTasks.values { task.cancel() }
            pendingTimeoutTasks.removeAll()
        }
    }

    /// Call after any newly captured clipboard item; no-ops unless it's an
    /// OTP-flagged item and a timeout-based trigger is active.
    public func handleCapturedItem(_ item: ClipboardItem) {
        guard enabled, item.sensitivityKind == .otp else { return }
        guard trigger == .timeout || trigger == .both else { return }
        scheduleTimeoutClear(for: item)
    }

    private func startObservingGlobalPaste() {
        guard cmdVToken == nil else { return }
        let cmdV = KeyCombo(keyCode: 9, modifiers: [.command]) // kVK_ANSI_V
        cmdVToken = hotkeyManager.register(cmdV, consume: false) { [weak self] in
            self?.handleGlobalPasteDetected()
        }
    }

    private func stopObservingGlobalPaste() {
        if let cmdVToken { hotkeyManager.unregister(cmdVToken) }
        cmdVToken = nil
    }

    private func handleGlobalPasteDetected() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: OTPAutoClearService.pasteSettleDelayNanoseconds)
            self?.clearIfCurrentPasteboardIsActiveOTP()
        }
    }

    private func scheduleTimeoutClear(for item: ClipboardItem) {
        pendingTimeoutTasks[item.uuid]?.cancel()
        let seconds = timeoutSeconds
        let uuid = item.uuid
        pendingTimeoutTasks[uuid] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds)) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.clearIfCurrentPasteboardIsActiveOTP()
            self?.pendingTimeoutTasks.removeValue(forKey: uuid)
        }
    }

    private func clearIfCurrentPasteboardIsActiveOTP() {
        guard let item = try? historyStore.mostRecentUnclearedOTPItem() else { return }
        guard NSPasteboard.general.string(forType: .string) == item.textPreview else { return }

        NSPasteboard.general.clearContents()
        try? historyStore.markOTPCleared(uuid: item.uuid)
        pendingTimeoutTasks[item.uuid]?.cancel()
        pendingTimeoutTasks.removeValue(forKey: item.uuid)
    }
}
