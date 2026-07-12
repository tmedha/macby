import Foundation

/// Heuristic one-time-passcode detector: 4-8 contiguous digits, allowing
/// common visual groupings like "123 456" or "123-456". Deliberately simple
/// and digit-only rather than a fuzzier scoring model — false positives are
/// low-cost (the feature is fully toggleable, and a false positive just wipes
/// the pasteboard a little eagerly) while false negatives just mean an OTP
/// isn't auto-cleared, so a conservative, easy-to-reason-about rule is
/// preferable to a speculative multi-signal heuristic.
public enum OTPDetector {
    private static let maxRawLength = 12
    private static let digitCountRange = 4...8

    public static func isLikelyOTP(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxRawLength else { return false }

        // Strip common OTP-display separators (spaces, dashes) before judging
        // digit count, but reject anything containing other characters.
        let stripped = trimmed.filter { $0 != " " && $0 != "-" }
        guard digitCountRange.contains(stripped.count) else { return false }
        return stripped.allSatisfy(\.isNumber)
    }
}
