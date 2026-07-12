import Testing
import Foundation
@testable import MacbyCore

@Suite struct AppSettingsTests {
    @Test func requireBiometricForSensitivePasteRoundTripsThroughJSON() throws {
        var settings = AppSettings.default
        #expect(settings.requireBiometricForSensitivePaste == true) // secure-by-default

        settings.requireBiometricForSensitivePaste = false
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(decoded.requireBiometricForSensitivePaste == false)
        // Sensitive-content detection/badging stays independent of the paste gate.
        #expect(decoded.sensitiveDetectionEnabled == true)
    }

    @Test func decodingAnOlderSettingsBlobMissingNewerFieldsFallsBackToDefaults() throws {
        // Simulates a settings blob persisted by an older build of the app,
        // before requireBiometricForSensitivePaste (and other later fields)
        // existed — decoding must not throw and must not silently reset
        // unrelated fields that ARE present in the old blob.
        let oldBlob = """
        {
            "maxHistoryItemCount": 750,
            "launchAtLogin": true,
            "monitoringPaused": false,
            "pasteAsPlainTextDefault": false,
            "excludedAppBundleIDs": ["com.example.PasswordManager"]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppSettings.self, from: oldBlob)

        #expect(decoded.maxHistoryItemCount == 750)
        #expect(decoded.launchAtLogin == true)
        #expect(decoded.excludedAppBundleIDs == ["com.example.PasswordManager"])
        #expect(decoded.requireBiometricForSensitivePaste == AppSettings.default.requireBiometricForSensitivePaste)
        #expect(decoded.otpClearTrigger == AppSettings.default.otpClearTrigger)
    }
}
