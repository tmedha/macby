import AppKit
import SwiftUI
import UniformTypeIdentifiers
import MacbyPersistence

public struct ExcludedAppsSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public var body: some View {
        Form {
            Section {
                if settingsStore.settings.excludedAppBundleIDs.isEmpty {
                    Text("No apps excluded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settingsStore.settings.excludedAppBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(displayName(for: bundleID))
                            Spacer()
                            Button {
                                settingsStore.settings.excludedAppBundleIDs.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button("Add App\u{2026}") { addApp() }
            } footer: {
                Text("Clipboard copies from excluded apps are never recorded \u{2014} useful for password managers and similar apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
    }

    private func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url) {
            let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleName"] as? String
            if let name { return name }
        }
        return bundleID
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier
        else { return }

        if !settingsStore.settings.excludedAppBundleIDs.contains(bundleID) {
            settingsStore.settings.excludedAppBundleIDs.append(bundleID)
        }
    }
}
