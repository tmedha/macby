import AppKit
import Foundation
import MacbyCore
import MacbyPersistence

/// Polls `NSPasteboard.general.changeCount` on a timer — macOS has no push
/// notification for pasteboard changes, but `changeCount` is a cheap property
/// read, so polling at ~250ms is effectively free (full contents are only
/// read when the count actually changes).
@MainActor
public final class PasteboardMonitor {
    public var pollInterval: TimeInterval
    public var isPaused: Bool = false
    public var excludedAppBundleIDs: Set<String> = []
    public var otpDetectionEnabled: Bool = true
    public var sensitiveDetectionEnabled: Bool = true
    public var aggressiveSSNDetectionEnabled: Bool = false
    /// Fired after every successful capture, on the main actor. Used by
    /// `OTPAutoClearService` to react to freshly captured OTP items without
    /// PasteboardMonitor needing to know that service exists.
    public var onCapture: ((ClipboardItem) -> Void)?

    private let pasteboard = NSPasteboard.general
    private let historyStore: HistoryStore
    private let blobStore: BlobStore
    private var lastChangeCount: Int
    private var timer: Timer?

    public init(historyStore: HistoryStore, blobStore: BlobStore, pollInterval: TimeInterval = 0.25) {
        self.historyStore = historyStore
        self.blobStore = blobStore
        self.pollInterval = pollInterval
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Marks the pasteboard's current contents as already-seen, so the next
    /// poll won't treat them as a new copy to capture. Used when Macby itself
    /// writes to the pasteboard during a paste — otherwise the monitor would
    /// re-ingest that write and the dedupe path in `HistoryStore.capture` would
    /// bump the item's `createdAt` to now, moving it to the top of history even
    /// when the user has "move pasted item to top" turned off. Must be called
    /// synchronously right after the write (both are on the main actor, so the
    /// timer can't tick in between).
    public func ignoreCurrentPasteboardState() {
        lastChangeCount = pasteboard.changeCount
    }

    private func tick() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        guard !isPaused else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        if let bundleID = frontmost?.bundleIdentifier, excludedAppBundleIDs.contains(bundleID) {
            return
        }

        guard let item = buildItem(sourceApp: frontmost) else { return }
        do {
            let captured = try historyStore.capture(item)
            onCapture?(captured)
        } catch {
            NSLog("PasteboardMonitor: failed to capture clipboard item: \(error)")
        }
    }

    private func buildItem(sourceApp: NSRunningApplication?) -> ClipboardItem? {
        let uuid = UUID().uuidString
        let sourceBundleID = sourceApp?.bundleIdentifier
        let sourceName = sourceApp?.localizedName

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !fileURLs.isEmpty {
            let paths = fileURLs.map(\.path)
            return ClipboardItem(
                uuid: uuid,
                contentType: .fileList,
                fileURLs: paths,
                contentHash: ContentHasher.hash(fileURLs: paths),
                sourceAppBundleID: sourceBundleID,
                sourceAppName: sourceName
            )
        }

        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let image = NSImage(data: imageData) {
            let pngData = image.pngData() ?? imageData
            let hash = ContentHasher.hash(data: pngData)
            let fullURL = try? blobStore.writeImage(pngData, uuid: uuid, suffix: "full")
            let thumbData = image.thumbnailPNGData(maxDimension: 240) ?? pngData
            let thumbURL = try? blobStore.writeImage(thumbData, uuid: uuid, suffix: "thumb")
            return ClipboardItem(
                uuid: uuid,
                contentType: .image,
                imageThumbnailPath: thumbURL?.path,
                imageFullPath: fullURL?.path,
                contentHash: hash,
                sourceAppBundleID: sourceBundleID,
                sourceAppName: sourceName
            )
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let hash = ContentHasher.hash(text: text)
            let isRTF = pasteboard.data(forType: .rtf) != nil
            var preview = text
            var fullTextPath: String?
            if text.count > BlobStore.textInlineThreshold {
                preview = String(text.prefix(BlobStore.textInlineThreshold))
                fullTextPath = try? blobStore.writeText(text, uuid: uuid).path
            }
            let isOTP = otpDetectionEnabled && OTPDetector.isLikelyOTP(text)
            var sensitivityKind: SensitivityKind?
            if isOTP {
                sensitivityKind = .otp
            } else if sensitiveDetectionEnabled {
                sensitivityKind = SensitiveContentDetector.detect(text, aggressiveSSNDetection: aggressiveSSNDetectionEnabled)
            }
            let isSensitive = sensitivityKind == .creditCard || sensitivityKind == .ssn

            return ClipboardItem(
                uuid: uuid,
                contentType: isRTF ? .rtf : .text,
                textPreview: preview,
                fullTextPath: fullTextPath,
                contentHash: hash,
                sourceAppBundleID: sourceBundleID,
                sourceAppName: sourceName,
                isSensitive: isSensitive,
                sensitivityKind: sensitivityKind
            )
        }

        return nil
    }
}
