import AppKit
import SwiftUI
import MacbyCore
import MacbySystem

/// A click-to-record shortcut field. Recording is implemented by overriding
/// `performKeyEquivalent(with:)`, not just `keyDown(with:)` — AppKit tries
/// `performKeyEquivalent` down the view hierarchy *before* falling back to
/// normal key dispatch, and auto-generates a default app menu (⌘, / ⌘Q / ⌘M /
/// ⌘W) even though Macby has no `WindowGroup`. Without this override,
/// recording e.g. ⌘Q while the Settings window is key would quit the app
/// instead of being captured, because the menu wins the race first.
public struct ShortcutRecorderField: View {
    @Binding var combo: KeyCombo?
    @State private var isRecording = false

    public init(combo: Binding<KeyCombo?>) {
        _combo = combo
    }

    public var body: some View {
        HStack(spacing: 6) {
            RecorderRepresentable(isRecording: $isRecording, combo: $combo)
                .frame(width: 120, height: 22)

            if combo != nil {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RecorderRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var combo: KeyCombo?

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onRecordingChange = { isRecording = $0 }
        view.onCommit = { combo = $0 }
        view.combo = combo
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.combo = combo
    }
}

private final class RecorderNSView: NSView {
    var combo: KeyCombo? {
        didSet { needsDisplay = true }
    }
    var onRecordingChange: ((Bool) -> Void)?
    var onCommit: ((KeyCombo?) -> Void)?

    private var isRecording = false {
        didSet {
            onRecordingChange?(isRecording)
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        handle(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handle(event)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc — cancel recording, keep prior value
            isRecording = false
            return
        }
        guard let newCombo = KeyCombo(nsEvent: event) else { return }
        combo = newCombo
        onCommit?(newCombo)
        isRecording = false
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Recording…" : (combo?.displayString ?? "Click to record")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: combo == nil && !isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]
        let size = text.size(withAttributes: attrs)
        let origin = CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: origin, withAttributes: attrs)
    }
}
