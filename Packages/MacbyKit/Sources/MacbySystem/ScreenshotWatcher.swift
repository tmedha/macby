import AppKit
import Foundation

/// Watches the macOS screenshot save folder for newly created screenshot
/// files (from Cmd+Shift+3/4 etc., which write a file to disk and never touch
/// the clipboard) and reports each one. The system screenshot tool doesn't put
/// its captures on the pasteboard, so without this there's no way for a
/// clipboard manager to see them.
@MainActor
public final class ScreenshotWatcher {
    /// Called on the main actor with the URL of each newly detected screenshot.
    public var onScreenshot: ((URL) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var directoryFD: Int32 = -1
    private var watchedDirectory: URL?
    private var knownFiles: Set<String> = []
    private var debounceWorkItem: DispatchWorkItem?

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "bmp"]

    public init() {}

    public var isRunning: Bool { source != nil }

    public func start() {
        stop()

        let directory = Self.screenshotDirectory()
        watchedDirectory = directory
        // Seed with what's already there so only files created *after* start
        // are treated as new — avoids re-ingesting the whole folder on launch.
        knownFiles = Self.imageFileNames(in: directory)

        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("ScreenshotWatcher: could not open \(directory.path) for watching (errno \(errno))")
            return
        }
        directoryFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleScan()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.directoryFD, fd >= 0 { close(fd) }
            self?.directoryFD = -1
        }
        self.source = source
        source.resume()
    }

    public func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
        watchedDirectory = nil
        knownFiles = []
    }

    // Directory-change events can arrive in bursts (the screenshot tool writes
    // a temp file then renames it); coalesce them before scanning.
    private func scheduleScan() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.scan() }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func scan() {
        guard let directory = watchedDirectory else { return }
        let current = Self.imageFileNames(in: directory)
        let newNames = current.subtracting(knownFiles)
        knownFiles = current

        for name in newNames {
            let url = directory.appendingPathComponent(name)
            if Self.isLikelyScreenshot(url) {
                onScreenshot?(url)
            }
        }
    }

    // MARK: - Detection

    /// The macOS screenshot save location: `com.apple.screencapture location`
    /// if the user set one, else the Desktop (the system default).
    static func screenshotDirectory() -> URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
    }

    private static func imageFileNames(in directory: URL) -> Set<String> {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        let images = names.filter {
            imageExtensions.contains(($0 as NSString).pathExtension.lowercased())
        }
        return Set(images)
    }

    /// A new image is treated as a screenshot when the screenshot tool's own
    /// `com.apple.metadata:kMDItemIsScreenCapture` extended attribute is set on
    /// it (written by the capture tool at file-creation time — immediate and
    /// authoritative, unlike the Spotlight-index copy of the same attribute
    /// which lags), with a filename-prefix check as a secondary fallback. A
    /// recency gate guards against ever ingesting a pre-existing file that only
    /// looks new to a rescan.
    private static func isLikelyScreenshot(_ url: URL) -> Bool {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let created = attrs[.creationDate] as? Date,
           Date().timeIntervalSince(created) > 60 {
            return false
        }

        if hasScreenCaptureExtendedAttribute(url) {
            return true
        }

        // Fallback for any capture path that doesn't set the xattr: match the
        // filename prefix the screenshot tool uses on this system.
        let name = url.lastPathComponent
        if let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "name"),
           !custom.isEmpty {
            return name.hasPrefix(custom)
        }
        return name.hasPrefix("Screenshot") || name.hasPrefix("Screen Shot")
    }

    private static func hasScreenCaptureExtendedAttribute(_ url: URL) -> Bool {
        let name = "com.apple.metadata:kMDItemIsScreenCapture"
        let length = getxattr(url.path, name, nil, 0, 0, 0)
        guard length > 0 else { return false }

        var data = Data(count: length)
        let read = data.withUnsafeMutableBytes {
            getxattr(url.path, name, $0.baseAddress, length, 0, 0)
        }
        guard read >= 0 else { return false }

        // The value is a binary-plist-encoded boolean.
        if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            if let flag = plist as? Bool { return flag }
            if let number = plist as? NSNumber { return number.boolValue }
        }
        // Attribute present but unparseable — its presence alone is a strong
        // screenshot signal, so accept rather than drop a real screenshot.
        return true
    }
}
