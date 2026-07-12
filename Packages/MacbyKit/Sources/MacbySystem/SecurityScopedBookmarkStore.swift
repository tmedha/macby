import Foundation
import MacbyCore
import MacbyPersistence

/// Persists user-chosen destination folders (e.g. where snips get saved) as
/// security-scoped bookmarks via `SettingsStore`. Macby is unsandboxed today,
/// so bookmarks aren't strictly required for permission purposes, but they're
/// the standard robust way to remember a folder across launches — they survive
/// the folder being renamed or moved on the same volume, via the stale-bookmark
/// refresh path below — and cost nothing extra to use now.
@MainActor
public final class SecurityScopedBookmarkStore {
    private let settingsStore: SettingsStore

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public func setFolder(_ url: URL, for category: FolderCategory) throws {
        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        settingsStore.settings.snipFolderBookmarks[category.rawValue] = bookmark
    }

    public func clearFolder(for category: FolderCategory) {
        settingsStore.settings.snipFolderBookmarks.removeValue(forKey: category.rawValue)
    }

    /// Resolves the bookmark to a URL, transparently re-persisting a refreshed
    /// bookmark if the stored one was stale. Caller is responsible for calling
    /// `startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()`
    /// around any file I/O.
    public func resolveFolder(for category: FolderCategory) -> URL? {
        guard let bookmark = settingsStore.settings.snipFolderBookmarks[category.rawValue] else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            try? setFolder(url, for: category)
        }
        return url
    }

    public func displayPath(for category: FolderCategory) -> String? {
        resolveFolder(for: category)?.path
    }
}
