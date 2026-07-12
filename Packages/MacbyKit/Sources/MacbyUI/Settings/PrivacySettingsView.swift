import SwiftUI
import MacbyPersistence

public struct PrivacySettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Detect sensitive data (credit cards, SSNs)", isOn: $settingsStore.settings.sensitiveDetectionEnabled)
            } footer: {
                Text("Flagged items are unaffected in Macby's own history list, but pasting one from Macby requires Touch ID below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settingsStore.settings.sensitiveDetectionEnabled {
                Section {
                    Toggle("Require Touch ID to paste sensitive items", isOn: $settingsStore.settings.requireBiometricForSensitivePaste)
                } footer: {
                    Text("Only applies to pasting via Macby's popover \u{2014} macOS has no way to gate a Cmd+V performed outside Macby for content copied elsewhere.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Aggressive SSN detection", isOn: $settingsStore.settings.aggressiveSSNDetectionEnabled)
                } footer: {
                    Text("Also flags bare 9-digit numbers as possible SSNs, not just xxx-xx-xxxx. Undashed numbers are ambiguous (phone numbers, order IDs, etc.) so this is more likely to flag things that aren't actually SSNs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
    }
}
