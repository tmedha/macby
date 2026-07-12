import SwiftUI
import MacbyCore
import MacbyPersistence
import MacbySystem

public struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    let historyStore: HistoryStore
    @State private var showClearConfirmation = false

    public init(settingsStore: SettingsStore, historyStore: HistoryStore) {
        self.settingsStore = settingsStore
        self.historyStore = historyStore
    }

    public var body: some View {
        Form {
            Section("History") {
                Stepper(
                    "Keep last \(settingsStore.settings.maxHistoryItemCount) items",
                    value: Binding(
                        get: { settingsStore.settings.maxHistoryItemCount },
                        set: {
                            settingsStore.settings.maxHistoryItemCount = $0
                            historyStore.maxHistoryItemCount = $0
                        }
                    ),
                    in: 10...20000,
                    step: 50
                )
                Button("Clear History…") { showClearConfirmation = true }
                    .confirmationDialog(
                        "Clear clipboard history?",
                        isPresented: $showClearConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Clear Unpinned Items", role: .destructive) {
                            try? historyStore.clearHistory(includingPinned: false)
                        }
                        Button("Clear Everything, Including Pinned", role: .destructive) {
                            try? historyStore.clearHistory(includingPinned: true)
                        }
                        Button("Cancel", role: .cancel) {}
                    }
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settingsStore.settings.launchAtLogin },
                    set: {
                        settingsStore.settings.launchAtLogin = $0
                        LaunchAtLoginManager.setEnabled($0)
                    }
                ))
                Toggle("Pause clipboard monitoring", isOn: $settingsStore.settings.monitoringPaused)
                Toggle("Paste as plain text by default", isOn: $settingsStore.settings.pasteAsPlainTextDefault)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
    }
}
