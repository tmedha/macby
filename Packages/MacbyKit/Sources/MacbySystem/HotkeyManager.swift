import CoreGraphics
import Foundation
import MacbyCore

/// One process-wide `CGEventTap` that every global keyboard shortcut in the
/// app routes through — the open-popover hotkey, the snip-capture hotkey, and
/// (in a future phase) a non-consuming Cmd+V observer for OTP auto-clear.
///
/// The tap is active (not `.listenOnly`) so matched combos can be swallowed
/// before they reach the frontmost app; `NSEvent.addGlobalMonitorForEvents`
/// (used elsewhere for the popover's outside-click dismiss) can never consume
/// events, which is why a tap is needed here instead. Whether an individual
/// registration consumes its event is a per-registration choice, not a
/// tap-wide mode — that's what lets a future non-blocking Cmd+V observer
/// share this same tap without any redesign.
public final class HotkeyManager: @unchecked Sendable {
    public typealias Token = UUID

    private struct Registration {
        let combo: KeyCombo
        let consume: Bool
        let handler: () -> Void
    }

    private var registrations: [Token: Registration] = [:]
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public private(set) var isRunning = false

    public init() {}

    deinit {
        stop()
    }

    @discardableResult
    public func register(_ combo: KeyCombo, consume: Bool = true, handler: @escaping () -> Void) -> Token {
        let token = Token()
        registrations[token] = Registration(combo: combo, consume: consume, handler: handler)
        return token
    }

    public func unregister(_ token: Token) {
        registrations.removeValue(forKey: token)
    }

    /// Attempts to create and enable the event tap. Returns false if creation
    /// failed — most commonly because Accessibility trust hasn't been granted
    /// yet. Safe to call again later (e.g. after the user grants permission).
    @discardableResult
    public func start() -> Bool {
        guard !isRunning else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyManagerEventTapCallback,
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        isRunning = true
        return true
    }

    public func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    /// Called on the main thread by the C callback below.
    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        var shouldConsume = false

        for registration in registrations.values where registration.combo.matches(keyCode: keyCode, flags: flags) {
            registration.handler()
            shouldConsume = shouldConsume || registration.consume
        }

        return shouldConsume ? nil : Unmanaged.passUnretained(event)
    }
}

private func hotkeyManagerEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleEvent(type: type, event: event)
}
