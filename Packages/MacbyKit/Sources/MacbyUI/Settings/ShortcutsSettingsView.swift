import SwiftUI
import MacbyPersistence

public struct ShortcutsSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public var body: some View {
        Form {
            Section {
                LabeledContent("Open Clipboard History") {
                    ShortcutRecorderField(combo: $settingsStore.settings.popoverHotkey)
                }
                LabeledContent("Start Snip Capture") {
                    ShortcutRecorderField(combo: $settingsStore.settings.snipCaptureHotkey)
                }
            } footer: {
                Text("Click a field, then press a key combination. Esc cancels recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
