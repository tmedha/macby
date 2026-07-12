import Foundation
import MacbyCore

public enum FileSaveRouterError: Error {
    case noFolderConfigured
    case accessDenied
}

/// Writes captured content to a user-chosen destination folder, resolved via
/// `SecurityScopedBookmarkStore`. Callers that shouldn't have a fast capture
/// flow interrupted by missing folder configuration (e.g. `SnipCaptureService`)
/// are expected to treat both error cases as non-fatal (`try?`).
@MainActor
public final class FileSaveRouter {
    private let bookmarkStore: SecurityScopedBookmarkStore
    private let dateFormatter: DateFormatter

    public init(bookmarkStore: SecurityScopedBookmarkStore) {
        self.bookmarkStore = bookmarkStore
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        self.dateFormatter = formatter
    }

    @discardableResult
    public func save(_ data: Data, category: FolderCategory, filenamePrefix: String = "Macby-Snip") throws -> URL {
        guard let folderURL = bookmarkStore.resolveFolder(for: category) else {
            throw FileSaveRouterError.noFolderConfigured
        }

        guard folderURL.startAccessingSecurityScopedResource() else {
            throw FileSaveRouterError.accessDenied
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let filename = "\(filenamePrefix)-\(dateFormatter.string(from: Date())).png"
        let fileURL = folderURL.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
