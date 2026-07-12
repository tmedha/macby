import AppKit
import Carbon.HIToolbox
import CoreGraphics
import MacbyCore

/// The NSEvent (shortcut recorder)/CGEvent (global hotkey tap) conversion
/// boundary for `KeyCombo`. `MacbyCore` stays free of AppKit/CoreGraphics
/// imports, so these live here where both sides are already available.
extension KeyCombo {
    /// Builds a combo from a key-equivalent/keyDown NSEvent. Returns nil for
    /// events with no modifier held — a recorder should require at least one
    /// modifier so plain letters aren't accidentally captured as shortcuts.
    public init?(nsEvent: NSEvent) {
        let modifiers = Modifiers(nsEventModifierFlags: nsEvent.modifierFlags)
        guard !modifiers.isEmpty else { return nil }
        self.init(keyCode: nsEvent.keyCode, modifiers: modifiers)
    }

    public func matches(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        self.keyCode == keyCode && modifiers == Modifiers(cgEventFlags: flags)
    }

    /// A short display form like "⌘⇧V".
    public var displayString: String {
        modifiers.displayPrefix + KeyCombo.keyCodeLabel(keyCode)
    }

    private static func keyCodeLabel(_ keyCode: UInt16) -> String {
        if let special = specialKeyLabels[keyCode] { return special }
        if let scalar = characterForKeyCode(keyCode) { return scalar.uppercased() }
        return "?"
    }

    private static let specialKeyLabels: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    private static func characterForKeyCode(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPointer).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let result = layoutData.withUnsafeBytes { rawBuffer -> OSStatus in
            guard let keyboardLayoutPtr = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return errSecParam
            }
            return UCKeyTranslate(
                keyboardLayoutPtr,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard result == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}

extension KeyCombo.Modifiers {
    init(nsEventModifierFlags flags: NSEvent.ModifierFlags) {
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        self = modifiers
    }

    init(cgEventFlags flags: CGEventFlags) {
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        self = modifiers
    }

    var displayPrefix: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}
