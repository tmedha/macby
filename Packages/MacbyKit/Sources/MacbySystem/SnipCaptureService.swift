import AppKit
import Foundation
import MacbyCore
import MacbyPersistence
import ScreenCaptureKit

/// Drives screen-region "snip" capture: shows the selection overlay, captures
/// the chosen display at native resolution via ScreenCaptureKit, crops in
/// software (rather than depending on `SCStreamConfiguration.sourceRect`
/// cropping-at-capture, whose reliability across macOS 14.x point releases is
/// unconfirmed), then routes the result to the pasteboard, clipboard history,
/// and (best-effort, non-blocking) a user-chosen folder on disk.
@MainActor
public final class SnipCaptureService {
    private let historyStore: HistoryStore
    private let blobStore: BlobStore
    private let fileSaveRouter: FileSaveRouter
    private let permissionsManager: PermissionsManager
    private var overlayController: SnipOverlayController?

    public init(
        historyStore: HistoryStore,
        blobStore: BlobStore,
        fileSaveRouter: FileSaveRouter,
        permissionsManager: PermissionsManager
    ) {
        self.historyStore = historyStore
        self.blobStore = blobStore
        self.fileSaveRouter = fileSaveRouter
        self.permissionsManager = permissionsManager
    }

    /// No-op if an overlay is already showing (e.g. hotkey held/repeated).
    public func startCapture() {
        guard overlayController == nil else { return }

        guard permissionsManager.isScreenRecordingTrusted || permissionsManager.requestScreenRecordingIfNeeded() else {
            presentScreenRecordingDeniedAlert()
            return
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let controller = SnipOverlayController()
        overlayController = controller
        controller.begin(screens: screens) { [weak self] result in
            self?.handleSelection(result)
        }
    }

    private func handleSelection(_ result: SnipSelectionResult) {
        overlayController = nil

        guard case let .selected(rect, screen) = result else { return }

        Task {
            // Give the compositor a moment to remove the overlay before
            // capturing, so Macby's own selection UI isn't baked into the shot.
            try? await Task.sleep(nanoseconds: 150_000_000)
            await capture(rect: rect, screen: screen)
        }
    }

    private func capture(rect: CGRect, screen: NSScreen) async {
        do {
            guard let displayID = screen.directDisplayID else { return }
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            configuration.showsCursor = false

            let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

            let pixelRect = SnipCoordinateConversion.pixelRect(
                for: rect,
                screenFrame: screen.frame,
                backingScaleFactor: screen.backingScaleFactor
            )
            guard let cropped = fullImage.cropping(to: pixelRect) else { return }

            handleCapturedImage(cropped)
        } catch {
            NSLog("SnipCaptureService: capture failed: \(error)")
        }
    }

    private func handleCapturedImage(_ cgImage: CGImage) {
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let pngData = image.pngData() else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(pngData, forType: .png)

        let uuid = UUID().uuidString
        let thumbData = image.thumbnailPNGData(maxDimension: 240) ?? pngData
        let fullURL = try? blobStore.writeImage(pngData, uuid: uuid, suffix: "full")
        let thumbURL = try? blobStore.writeImage(thumbData, uuid: uuid, suffix: "thumb")

        var savedPath: String?
        var savedCategory: String?
        if let savedURL = try? fileSaveRouter.save(pngData, category: .snips) {
            savedPath = savedURL.path
            savedCategory = FolderCategory.snips.rawValue
        }

        let item = ClipboardItem(
            uuid: uuid,
            contentType: .image,
            imageThumbnailPath: thumbURL?.path,
            imageFullPath: fullURL?.path,
            contentHash: ContentHasher.hash(data: pngData),
            savedToFolderPath: savedPath,
            savedFolderCategory: savedCategory
        )
        do {
            try historyStore.capture(item)
        } catch {
            NSLog("SnipCaptureService: failed to record captured snip: \(error)")
        }
    }

    private func presentScreenRecordingDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Access Needed"
        alert.informativeText = "Macby needs Screen Recording access to capture snips. Grant access in System Settings, then relaunch Macby."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            permissionsManager.openScreenRecordingSettings()
        }
    }
}

private extension NSScreen {
    var directDisplayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
