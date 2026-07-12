import Foundation

/// Codable snapshot of user-configurable settings. Persisted via UserDefaults
/// (see SettingsStore in MacbyPersistence) rather than SQLite — small and schema-fluid.
public struct AppSettings: Codable, Equatable, Sendable {
    public var maxHistoryItemCount: Int
    public var launchAtLogin: Bool
    public var monitoringPaused: Bool
    public var pasteAsPlainTextDefault: Bool
    public var excludedAppBundleIDs: [String]

    public static let `default` = AppSettings(
        maxHistoryItemCount: 500,
        launchAtLogin: false,
        monitoringPaused: false,
        pasteAsPlainTextDefault: false,
        excludedAppBundleIDs: []
    )

    public init(
        maxHistoryItemCount: Int,
        launchAtLogin: Bool,
        monitoringPaused: Bool,
        pasteAsPlainTextDefault: Bool,
        excludedAppBundleIDs: [String]
    ) {
        self.maxHistoryItemCount = maxHistoryItemCount
        self.launchAtLogin = launchAtLogin
        self.monitoringPaused = monitoringPaused
        self.pasteAsPlainTextDefault = pasteAsPlainTextDefault
        self.excludedAppBundleIDs = excludedAppBundleIDs
    }
}
