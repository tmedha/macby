import SwiftUI
import MacbyCore
import MacbySystem

public struct PopoverRootView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var presentationState: PopoverPresentationState
    let onPaste: (ClipboardItem) -> Void
    let onClose: () -> Void
    let onOpenAccessibilitySettings: () -> Void

    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    public init(
        viewModel: HistoryViewModel,
        permissionsManager: PermissionsManager,
        presentationState: PopoverPresentationState,
        onPaste: @escaping (ClipboardItem) -> Void,
        onClose: @escaping () -> Void,
        onOpenAccessibilitySettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.permissionsManager = permissionsManager
        self.presentationState = presentationState
        self.onPaste = onPaste
        self.onClose = onClose
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
    }

    public var body: some View {
        contentStack
            .frame(width: 360, height: 420)
            .popoverGlassBackground()
            .onAppear {
                searchFocused = true
                permissionsManager.refresh()
            }
            // .onAppear above only fires once ever (the panel is created once
            // and reused via orderFront/orderOut on later opens) — this is what
            // makes refocusing actually work on every subsequent open, which is
            // what arrow-key navigation depends on without first clicking the
            // field.
            .onChange(of: presentationState.showCount) { _, _ in
                searchFocused = true
            }
            .onChange(of: viewModel.items) { _, _ in selectedIndex = 0 }
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            if !permissionsManager.isAccessibilityTrusted {
                permissionBanner
                Divider()
            }
            searchField
            Divider()
            list
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Accessibility access needed for shortcuts & paste")
                .font(.system(size: 11))
            Spacer()
            GlassOrPlainButton("Fix\u{2026}", action: onOpenAccessibilitySettings)
                .font(.system(size: 11))
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .searchFieldGlassBackground()
        .padding(8)
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.return) { selectCurrent(); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.uuid) { index, item in
                        row(item: item, index: index)
                    }
                }
                .padding(6)
            }
            .onChange(of: selectedIndex) { _, newValue in
                guard viewModel.items.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(viewModel.items[newValue].uuid, anchor: nil)
                }
            }
        }
    }

    private func row(item: ClipboardItem, index: Int) -> some View {
        ClipboardItemRow(
            item: item,
            isSelected: index == selectedIndex,
            onSelect: {
                selectedIndex = index
                onPaste(item)
            }
        )
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") { viewModel.togglePin(item) }
            Button("Delete", role: .destructive) { viewModel.delete(item) }
        }
    }

    private func move(_ delta: Int) {
        guard !viewModel.items.isEmpty else { return }
        selectedIndex = max(0, min(viewModel.items.count - 1, selectedIndex + delta))
    }

    private func selectCurrent() {
        guard viewModel.items.indices.contains(selectedIndex) else { return }
        onPaste(viewModel.items[selectedIndex])
    }
}

/// A button that renders with the real Liquid Glass button style on macOS 26+,
/// falling back to the standard bordered style on older systems — Macby's
/// deployment target (macOS 14) predates Liquid Glass, so every glass API use
/// needs an availability fallback rather than assuming it exists.
struct GlassOrPlainButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            Button(title, action: action)
                .buttonStyle(.glass)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
        }
    }
}

private extension View {
    /// The popover's outer panel background: real Liquid Glass on macOS 26+,
    /// the previous frosted-material look on older systems.
    @ViewBuilder
    func popoverGlassBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            self.background(.regularMaterial)
        }
    }

    @ViewBuilder
    func searchFieldGlassBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self.background(Capsule().fill(Color.primary.opacity(0.06)))
        }
    }
}
