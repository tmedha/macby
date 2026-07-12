import Foundation

/// Detects credit card numbers (Luhn-validated) and SSNs in copied text.
/// Like `OTPDetector`, this checks whether the *entire* trimmed clipboard
/// content matches — not an arbitrary substring within a longer sentence —
/// which keeps the rule simple and conservative rather than a speculative
/// multi-signal scan.
public enum SensitiveContentDetector {
    public static func detect(_ text: String, aggressiveSSNDetection: Bool) -> SensitivityKind? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if isSSN(trimmed, aggressive: aggressiveSSNDetection) {
            return .ssn
        }
        if isCreditCard(trimmed) {
            return .creditCard
        }
        return nil
    }

    // MARK: - Credit card (Luhn-validated)

    private static func isCreditCard(_ text: String) -> Bool {
        let stripped = text.filter { $0 != " " && $0 != "-" }
        guard (13...19).contains(stripped.count), stripped.allSatisfy(\.isNumber) else { return false }
        return luhnIsValid(stripped)
    }

    private static func luhnIsValid(_ digits: String) -> Bool {
        var sum = 0
        for (index, digit) in digits.reversed().compactMap(\.wholeNumberValue).enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }

    // MARK: - SSN

    // Dashed format (xxx-xx-xxxx) is matched by default; a bare 9-digit
    // sequence is only treated as a possible SSN when the user opts in to
    // "aggressive" detection — undashed 9-digit numbers are inherently
    // ambiguous (phone numbers, order IDs, etc.) so defaulting to noisy
    // detection there would erode trust in the whole feature.
    private static func isSSN(_ text: String, aggressive: Bool) -> Bool {
        if let match = matchDashedSSN(text) {
            return isPlausibleSSN(area: match.area, group: match.group, serial: match.serial)
        }
        if aggressive, text.count == 9, text.allSatisfy(\.isNumber) {
            let area = String(text.prefix(3))
            let group = String(text.dropFirst(3).prefix(2))
            let serial = String(text.suffix(4))
            return isPlausibleSSN(area: area, group: group, serial: serial)
        }
        return false
    }

    private static func matchDashedSSN(_ text: String) -> (area: String, group: String, serial: String)? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 3, parts[1].count == 2, parts[2].count == 4,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
        else { return nil }
        return (String(parts[0]), String(parts[1]), String(parts[2]))
    }

    // Rejects the well-known invalid SSN ranges (area 000/666/900-999, group
    // 00, serial 0000) to cut down on false positives from arbitrary numbers.
    private static func isPlausibleSSN(area: String, group: String, serial: String) -> Bool {
        guard let areaNum = Int(area), let groupNum = Int(group), let serialNum = Int(serial) else { return false }
        guard area != "000", area != "666", areaNum < 900 else { return false }
        guard groupNum != 0 else { return false }
        guard serialNum != 0 else { return false }
        return true
    }
}
