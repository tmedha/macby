import AppKit
import SwiftUI
import MacbyCore
import MacbySystem

public struct FolderRoutingSettingsView: View {
    let bookmarkStore: SecurityScopedBookmarkStore
    @State private var snipsPath: String?

    public init(bookmarkStore: SecurityScopedBookmarkStore) {
        self.bookmarkStore = bookmarkStore
    }

    public var body: some View {
        Form {
            Section {
                LabeledContent("Snips") {
                    HStack {
                        Text(snipsPath ?? "Not Set")
                            .foregroundStyle(snipsPath == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") { chooseFolder() }
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

    private func chooseFolder() {
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
