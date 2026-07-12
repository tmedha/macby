import SwiftUI
import MacbyCore
import MacbyPersistence

public struct OTPSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Detect one-time passcodes", isOn: $settingsStore.settings.otpDetectionEnabled)
            } footer: {
                Text("Copied text that looks like a 4\u{2013}8 digit passcode is flagged and can be auto-cleared from the clipboard after use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settingsStore.settings.otpDetectionEnabled {
                Section {
                    Picker("Clear when", selection: $settingsStore.settings.otpClearTrigger) {
                        Text("A paste (\u{2318}V) is detected").tag(OTPClearTrigger.onPasteDetected)
                        Text("A timeout elapses").tag(OTPClearTrigger.timeout)
                        Text("Either happens first").tag(OTPClearTrigger.both)
                    }
                    .pickerStyle(.radioGroup)

                    if settingsStore.settings.otpClearTrigger != .onPasteDetected {
                        Stepper(
                            "Timeout: \(settingsStore.settings.otpClearTimeoutSeconds)s",
                            value: $settingsStore.settings.otpClearTimeoutSeconds,
                            in: 5...300,
                            step: 5
                        )
                    }
                } header: {
                    Text("Clear Trigger")
                } footer: {
                    Text("Paste detection is best-effort: it clears shortly after a \u{2318}V is seen anywhere, not only pastes from Macby.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
