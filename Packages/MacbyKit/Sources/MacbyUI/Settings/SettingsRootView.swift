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
            GeneralSettingsView(settingsStore: settingsStore, historyStore: historyStore)
                .tabItem { Label("General", systemImage: "gearshape") }

            ShortcutsSettingsView(settingsStore: settingsStore)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            FolderRoutingSettingsView(bookmarkStore: bookmarkStore)
                .tabItem { Label("Folders", systemImage: "folder") }
        }
        .frame(width: 420, height: 360)
    }
}
