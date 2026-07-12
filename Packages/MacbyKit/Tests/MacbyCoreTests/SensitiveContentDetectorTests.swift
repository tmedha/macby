import Testing
@testable import MacbyCore

@Suite struct SensitiveContentDetectorTests {
    // Well-known published test/dummy card numbers (not real cards), used
    // industry-wide for exercising Luhn validation.
    @Test func detectsLuhnValidVisaTestNumber() {
        #expect(SensitiveContentDetector.detect("4111111111111111", aggressiveSSNDetection: false) == .creditCard)
    }

    @Test func detectsLuhnValidMastercardTestNumber() {
        #expect(SensitiveContentDetector.detect("5500005555555559", aggressiveSSNDetection: false) == .creditCard)
    }

    @Test func detectsLuhnValidAmexTestNumber() {
        #expect(SensitiveContentDetector.detect("378282246310005", aggressiveSSNDetection: false) == .creditCard)
    }

    @Test func detectsCardNumberWithSpacesOrDashes() {
        #expect(SensitiveContentDetector.detect("4111 1111 1111 1111", aggressiveSSNDetection: false) == .creditCard)
        #expect(SensitiveContentDetector.detect("4111-1111-1111-1111", aggressiveSSNDetection: false) == .creditCard)
    }

    @Test func rejectsLuhnInvalidNumber() {
        #expect(SensitiveContentDetector.detect("4111111111111112", aggressiveSSNDetection: false) == nil)
    }

    @Test func rejectsWrongLengthDigitSequence() {
        #expect(SensitiveContentDetector.detect("41111111", aggressiveSSNDetection: false) == nil)
    }

    @Test func detectsDashedSSN() {
        #expect(SensitiveContentDetector.detect("123-45-6789", aggressiveSSNDetection: false) == .ssn)
    }

    @Test func rejectsInvalidSSNAreaZero() {
        #expect(SensitiveContentDetector.detect("000-45-6789", aggressiveSSNDetection: false) == nil)
    }

    @Test func rejectsInvalidSSNArea666() {
        #expect(SensitiveContentDetector.detect("666-45-6789", aggressiveSSNDetection: false) == nil)
    }

    @Test func rejectsInvalidSSNAreaAtOrAbove900() {
        #expect(SensitiveContentDetector.detect("900-45-6789", aggressiveSSNDetection: false) == nil)
    }

    @Test func rejectsInvalidSSNGroupZero() {
        #expect(SensitiveContentDetector.detect("123-00-6789", aggressiveSSNDetection: false) == nil)
    }

    @Test func rejectsInvalidSSNSerialZero() {
        #expect(SensitiveContentDetector.detect("123-45-0000", aggressiveSSNDetection: false) == nil)
    }

    @Test func bareNineDigitSSNRequiresAggressiveModeOptIn() {
        #expect(SensitiveContentDetector.detect("123456789", aggressiveSSNDetection: false) == nil)
        #expect(SensitiveContentDetector.detect("123456789", aggressiveSSNDetection: true) == .ssn)
    }

    @Test func rejectsOrdinaryText() {
        #expect(SensitiveContentDetector.detect("just some regular copied text", aggressiveSSNDetection: false) == nil)
    }

    @Test func rejectsOTPLengthNumberAsCreditCard() {
        // 4-8 digit numbers (OTP territory) must never be misclassified as a card.
        #expect(SensitiveContentDetector.detect("123456", aggressiveSSNDetection: false) == nil)
    }
}
