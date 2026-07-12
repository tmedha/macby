import SwiftUI
import MacbySystem

public struct OnboardingView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    let onRequestAccessibility: () -> Void
    let onFinish: () -> Void

    private var isAccessibilityTrusted: Bool { permissionsManager.isAccessibilityTrusted }

    public init(
        permissionsManager: PermissionsManager,
        onRequestAccessibility: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.permissionsManager = permissionsManager
        self.onRequestAccessibility = onRequestAccessibility
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                Text("Welcome to Macby")
                    .font(.title2.bold())
            }

            Text("Macby lives in your menu bar and keeps a history of everything you copy. Clipboard history works right away \u{2014} no permission needed for that.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Label("Global keyboard shortcuts and pasting on your behalf need Accessibility access.", systemImage: "keyboard")
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Image(systemName: isAccessibilityTrusted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isAccessibilityTrusted ? .green : .secondary)
                    Text(isAccessibilityTrusted ? "Accessibility access granted" : "Accessibility access not yet granted")
                        .font(.callout)
                    Spacer()
                    if !isAccessibilityTrusted {
                        Button("Grant Access\u{2026}", action: onRequestAccessibility)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
            }

            Text("Screen capture (for snips) and Touch ID (for sensitive pastes) will ask only when you first use those features.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Spacer()
                Button("Get Started", action: onFinish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420, height: 360)
    }
}
