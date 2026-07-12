import Foundation
import Combine
import MacbyCore

@MainActor
public final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private static let key = "AppSettings.v1"

    @Published public var settings: AppSettings {
        didSet { persist() }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
