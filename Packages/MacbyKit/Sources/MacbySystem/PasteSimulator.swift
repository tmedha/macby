import AppKit
import Carbon.HIToolbox
import Foundation
import MacbyCore
import MacbyPersistence

/// Sets the system pasteboard to a history item's payload, then synthesizes a
/// Cmd+V key event so the frontmost app receives it — this is how clicking an
/// item in Macby's popover results in an actual paste.
@MainActor
public final class PasteSimulator {
    private let blobStore: BlobStore

    public init(blobStore: BlobStore) {
        self.blobStore = blobStore
    }

    /// `targetApp` is whichever app was frontmost before Macby's popover
    /// activated itself — it must be reactivated before the synthetic Cmd+V
    /// is posted, or the keystroke has no meaningful target to land in (Macby
    /// itself has no visible window once the popover is hidden). Activation
    /// is asynchronous, so this briefly waits for it to actually take effect.
    public func paste(_ item: ClipboardItem, asPlainText: Bool = false, targetApp: NSRunningApplication?) async {
        write(item, asPlainText: asPlainText)

        if let targetApp, !targetApp.isActive {
            targetApp.activate()
            await waitUntilActive(targetApp, timeoutNanoseconds: 500_000_000)
        }

        synthesizeCommandV()
    }

    /// Polls rather than sleeping a fixed duration — activation time varies
    /// (e.g. an app waking from a suspended state takes longer), and a fixed
    /// delay would either race ahead of slow activations or needlessly delay
    /// fast ones. Proceeds anyway on timeout rather than never pasting.
    private func waitUntilActive(_ app: NSRunningApplication, timeoutNanoseconds: UInt64) async {
        let pollInterval: UInt64 = 20_000_000
        var waited: UInt64 = 0
        while !app.isActive && waited < timeoutNanoseconds {
            try? await Task.sleep(nanoseconds: pollInterval)
            waited += pollInterval
        }
    }

    public func write(_ item: ClipboardItem, asPlainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .text, .rtf:
            let text = fullText(for: item) ?? item.textPreview ?? ""
            pasteboard.setString(text, forType: .string)
        case .image:
            guard !asPlainText, let path = item.imageFullPath,
                  let data = FileManager.default.contents(atPath: path) else { return }
            pasteboard.setData(data, forType: .png)
        case .fileList:
            guard let urls = item.fileURLs else { return }
            let nsurls = urls.map { NSURL(fileURLWithPath: $0) }
            pasteboard.writeObjects(nsurls)
        case .url:
            if let text = item.textPreview { pasteboard.setString(text, forType: .string) }
        }
    }

    private func fullText(for item: ClipboardItem) -> String? {
        guard let path = item.fullTextPath else { return item.textPreview }
        return blobStore.readText(at: URL(fileURLWithPath: path)) ?? item.textPreview
    }

    private func synthesizeCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
