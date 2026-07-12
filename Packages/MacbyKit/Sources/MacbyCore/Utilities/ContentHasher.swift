import Foundation
import CryptoKit

public enum ContentHasher {
    public static func hash(text: String) -> String {
        hash(data: Data(text.utf8))
    }

    public static func hash(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func hash(fileURLs: [String]) -> String {
        hash(text: fileURLs.sorted().joined(separator: "\n"))
    }
}
