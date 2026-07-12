import Foundation

/// When a detected one-time-passcode should be wiped from the system
/// pasteboard. Both mechanisms are heuristic best-effort — see
/// `OTPAutoClearService` in MacbySystem for the caveats of each.
public enum OTPClearTrigger: String, Codable, CaseIterable, Hashable, Sendable {
    case onPasteDetected
    case timeout
    case both
}
