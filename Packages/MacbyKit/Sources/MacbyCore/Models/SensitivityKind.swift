import Foundation

public enum SensitivityKind: String, Codable, CaseIterable, Sendable {
    case otp
    case creditCard
    case ssn
}
