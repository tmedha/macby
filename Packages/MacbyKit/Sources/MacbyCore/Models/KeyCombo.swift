import Foundation

/// A framework-agnostic representation of a global keyboard shortcut. Kept free
/// of AppKit/CoreGraphics imports so it can live in `AppSettings`; the NSEvent/
/// CGEvent conversion boundary lives in MacbySystem/KeyComboConversions.swift.
public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Modifiers

    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌘⇧V, the default "open popover" shortcut (kVK_ANSI_V == 9).
    public static let defaultPopoverHotkey = KeyCombo(keyCode: 9, modifiers: [.command, .shift])
}
