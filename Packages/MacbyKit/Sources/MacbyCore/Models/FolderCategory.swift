import Foundation

/// A category of content that can be routed to a user-chosen destination
/// folder on disk (in addition to clipboard history). Only `.snips` exists
/// today; more categories can be added later without a settings schema change
/// since `AppSettings.snipFolderBookmarks` is keyed by the raw string value.
public enum FolderCategory: String, Codable, CaseIterable, Sendable {
    case snips
}
