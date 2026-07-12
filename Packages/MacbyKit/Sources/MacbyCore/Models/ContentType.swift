import Foundation

public enum ContentType: String, Codable, CaseIterable, Sendable {
    case text
    case rtf
    case image
    case fileList
    case url
}
