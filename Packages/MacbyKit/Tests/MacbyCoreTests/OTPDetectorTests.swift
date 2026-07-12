import Testing
@testable import MacbyCore

@Suite struct OTPDetectorTests {
    @Test func acceptsPlainSixDigitCode() {
        #expect(OTPDetector.isLikelyOTP("123456"))
    }

    @Test func acceptsFourDigitCode() {
        #expect(OTPDetector.isLikelyOTP("1234"))
    }

    @Test func acceptsEightDigitCode() {
        #expect(OTPDetector.isLikelyOTP("12345678"))
    }

    @Test func acceptsSpaceGroupedCode() {
        #expect(OTPDetector.isLikelyOTP("123 456"))
    }

    @Test func acceptsDashGroupedCode() {
        #expect(OTPDetector.isLikelyOTP("123-456"))
    }

    @Test func acceptsCodeWithSurroundingWhitespace() {
        #expect(OTPDetector.isLikelyOTP("  123456  "))
    }

    @Test func rejectsTooShortNumber() {
        #expect(!OTPDetector.isLikelyOTP("123"))
    }

    @Test func rejectsTooLongNumber() {
        #expect(!OTPDetector.isLikelyOTP("123456789012"))
    }

    @Test func rejectsAlphanumericText() {
        #expect(!OTPDetector.isLikelyOTP("abc123"))
    }

    @Test func rejectsOrdinaryWord() {
        #expect(!OTPDetector.isLikelyOTP("hello"))
    }

    @Test func rejectsEmptyString() {
        #expect(!OTPDetector.isLikelyOTP(""))
    }

    @Test func rejectsLongSentenceOfDigitsAndWords() {
        #expect(!OTPDetector.isLikelyOTP("Your order #123456 has shipped"))
    }
}
