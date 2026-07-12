import Foundation

/// Writes large clipboard payloads (images, oversized text) to disk under
/// Application Support, keeping the SQLite row itself small and cheap to diff.
public final class BlobStore {
    public static let textInlineThreshold = 500

    private let rootURL: URL

    public init(rootURL: URL = BlobStore.defaultRootURL) {
        self.rootURL = rootURL
        try? FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent("images"), withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent("text"), withIntermediateDirectories: true
        )
    }

    public static var defaultRootURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return appSupport
            .appendingPathComponent("Macby", isDirectory: true)
            .appendingPathComponent("blobs", isDirectory: true)
    }

    public func writeImage(_ data: Data, uuid: String, suffix: String) throws -> URL {
        let url = rootURL.appendingPathComponent("images/\(uuid)_\(suffix).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    public func writeText(_ text: String, uuid: String) throws -> URL {
        let url = rootURL.appendingPathComponent("text/\(uuid).txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public func readText(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}
