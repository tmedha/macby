import AppKit
import SwiftUI
import MacbyCore
import MacbyPersistence
import MacbySystem

public struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    let historyStore: HistoryStore
    let bookmarkStore: SecurityScopedBookmarkStore
    @State private var showClearConfirmation = false
    @State private var snipsPath: String?

    public init(settingsStore: SettingsStore, historyStore: HistoryStore, bookmarkStore: SecurityScopedBookmarkStore) {
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.bookmarkStore = bookmarkStore
    }

    public var body: some View {
        Form {
            Section {
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
                Toggle("Move pasted item to top of list", isOn: $settingsStore.settings.bumpPastedItemToTop)
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
            } header: {
                Text("History")
            } footer: {
                Text("When on, pasting an item from Macby brings it back to the top of the list \u{2014} independent of when it was originally copied — so items you reuse often stay easy to find.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Section {
                Toggle("Add system screenshots to clipboard", isOn: $settingsStore.settings.ingestSystemScreenshots)
            } footer: {
                Text("Watches your macOS screenshot save location (Desktop by default) and adds new screenshots \u{2014} taken with \u{2318}\u{21E7}3, \u{2318}\u{21E7}4, etc. \u{2014} to the clipboard automatically. macOS may ask to grant Macby access to that folder the first time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Snips") {
                    HStack {
                        Text(snipsPath ?? "Not Set")
                            .foregroundStyle(snipsPath == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") { chooseSnipsFolder() }
                        if snipsPath != nil {
                            Button("Clear") {
                                bookmarkStore.clearFolder(for: .snips)
                                snipsPath = nil
                            }
                        }
                    }
                }
            } footer: {
                Text("Screen captures made with the snip hotkey are saved here, in addition to being added to clipboard history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { snipsPath = bookmarkStore.displayPath(for: .snips) }
    }

    private func chooseSnipsFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? bookmarkStore.setFolder(url, for: .snips)
        snipsPath = bookmarkStore.displayPath(for: .snips)
    }
}
