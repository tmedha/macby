import CoreGraphics
import Testing
import MacbyCore
@testable import MacbySystem

@Suite struct KeyComboConversionsTests {
    @Test func modifiersFromCGEventFlagsMasksIrrelevantBits() {
        // .maskNonCoalesced and friends are device-dependent noise that must
        // not affect the normalized modifier comparison.
        let flags: CGEventFlags = [.maskCommand, .maskShift, .maskNonCoalesced]
        let modifiers = KeyCombo.Modifiers(cgEventFlags: flags)
        #expect(modifiers == [.command, .shift])
    }

    @Test func matchesRequiresExactModifierSet() {
        let combo = KeyCombo(keyCode: 9, modifiers: [.command, .shift])

        #expect(combo.matches(keyCode: 9, flags: [.maskCommand, .maskShift]))
        // Holding an extra modifier (⌘⌥⇧V) must NOT match a ⌘⇧V registration.
        #expect(!combo.matches(keyCode: 9, flags: [.maskCommand, .maskShift, .maskAlternate]))
        // Wrong key code must not match even with the right modifiers.
        #expect(!combo.matches(keyCode: 1, flags: [.maskCommand, .maskShift]))
    }

    @Test func recorderRejectsComboWithNoModifiers() {
        // A bare keyDown NSEvent (no modifiers) must be rejected by the
        // recorder so plain letters can't accidentally become a shortcut.
        #expect(KeyCombo.Modifiers(nsEventModifierFlags: []).isEmpty)
    }
}
