import Foundation

/// Codable snapshot of user-configurable settings. Persisted via UserDefaults
/// (see SettingsStore in MacbyPersistence) rather than SQLite — small and schema-fluid.
public struct AppSettings: Codable, Equatable, Sendable {
    public var maxHistoryItemCount: Int
    public var launchAtLogin: Bool
    public var monitoringPaused: Bool
    public var pasteAsPlainTextDefault: Bool
    public var excludedAppBundleIDs: [String]
    public var popoverHotkey: KeyCombo?
    public var snipCaptureHotkey: KeyCombo?
    public var snipFolderBookmarks: [String: Data]

    public static let `default` = AppSettings(
        maxHistoryItemCount: 500,
        launchAtLogin: false,
        monitoringPaused: false,
        pasteAsPlainTextDefault: false,
        excludedAppBundleIDs: [],
        popoverHotkey: .defaultPopoverHotkey,
        snipCaptureHotkey: nil,
        snipFolderBookmarks: [:]
    )

    public init(
        maxHistoryItemCount: Int,
        launchAtLogin: Bool,
        monitoringPaused: Bool,
        pasteAsPlainTextDefault: Bool,
        excludedAppBundleIDs: [String],
        popoverHotkey: KeyCombo?,
        snipCaptureHotkey: KeyCombo?,
        snipFolderBookmarks: [String: Data]
    ) {
        self.maxHistoryItemCount = maxHistoryItemCount
        self.launchAtLogin = launchAtLogin
        self.monitoringPaused = monitoringPaused
        self.pasteAsPlainTextDefault = pasteAsPlainTextDefault
        self.excludedAppBundleIDs = excludedAppBundleIDs
        self.popoverHotkey = popoverHotkey
        self.snipCaptureHotkey = snipCaptureHotkey
        self.snipFolderBookmarks = snipFolderBookmarks
    }

    // Custom Decodable so that adding new fields in the future never breaks
    // decoding of settings blobs persisted by older versions of the app —
    // every field falls back to `.default`'s value when missing from the
    // stored JSON, instead of the whole decode throwing and silently
    // resetting every setting (see SettingsStore.init).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default
        maxHistoryItemCount = try container.decodeIfPresent(Int.self, forKey: .maxHistoryItemCount) ?? defaults.maxHistoryItemCount
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        monitoringPaused = try container.decodeIfPresent(Bool.self, forKey: .monitoringPaused) ?? defaults.monitoringPaused
        pasteAsPlainTextDefault = try container.decodeIfPresent(Bool.self, forKey: .pasteAsPlainTextDefault) ?? defaults.pasteAsPlainTextDefault
        excludedAppBundleIDs = try container.decodeIfPresent([String].self, forKey: .excludedAppBundleIDs) ?? defaults.excludedAppBundleIDs
        popoverHotkey = try container.decodeIfPresent(KeyCombo.self, forKey: .popoverHotkey) ?? defaults.popoverHotkey
        snipCaptureHotkey = try container.decodeIfPresent(KeyCombo.self, forKey: .snipCaptureHotkey) ?? defaults.snipCaptureHotkey
        snipFolderBookmarks = try container.decodeIfPresent([String: Data].self, forKey: .snipFolderBookmarks) ?? defaults.snipFolderBookmarks
    }
}
