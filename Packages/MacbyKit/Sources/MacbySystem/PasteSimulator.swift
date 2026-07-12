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

    public func paste(_ item: ClipboardItem, asPlainText: Bool = false) {
        write(item, asPlainText: asPlainText)
        synthesizeCommandV()
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
