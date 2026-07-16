import SwiftUI
import MacbyPersistence
import MacbySystem

public struct SettingsRootView: View {
    let settingsStore: SettingsStore
    let historyStore: HistoryStore
    let bookmarkStore: SecurityScopedBookmarkStore

    public init(settingsStore: SettingsStore, historyStore: HistoryStore, bookmarkStore: SecurityScopedBookmarkStore) {
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.bookmarkStore = bookmarkStore
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore, historyStore: historyStore, bookmarkStore: bookmarkStore)
                .tabItem { Label("General", systemImage: "gearshape") }

            ShortcutsSettingsView(settingsStore: settingsStore)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            PrivacySettingsView(settingsStore: settingsStore)
                .tabItem { Label("Privacy", systemImage: "lock.shield") }

            ExcludedAppsSettingsView(settingsStore: settingsStore)
                .tabItem { Label("Excluded Apps", systemImage: "nosign") }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 420, idealHeight: 480)
    }
}
