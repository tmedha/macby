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
        VStack(spacing: 0) {
            if !permissionsManager.isAccessibilityTrusted {
                permissionBanner
                Divider()
            }
            searchField
            Divider()
            list
        }
        .frame(width: 360, height: 420)
        .background(.regularMaterial)
        .onAppear {
            searchFocused = true
            permissionsManager.refresh()
        }
        // .onAppear above only fires once ever (the panel is created once and
        // reused via orderFront/orderOut on later opens) — this is what makes
        // refocusing actually work on every subsequent open, which is what
        // arrow-key navigation depends on without first clicking the field.
        .onChange(of: presentationState.showCount) { _, _ in
            searchFocused = true
        }
        .onChange(of: viewModel.items) { _, _ in selectedIndex = 0 }
    }

    private var permissionBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Accessibility access needed for shortcuts & paste")
                .font(.system(size: 11))
            Spacer()
            Button("Fix\u{2026}", action: onOpenAccessibilitySettings)
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
        .padding(10)
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.return) { selectCurrent(); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    // Non-file items (text/image/rtf/url) render first, reverse-chronological;
    // file items render below a visually heavier divider. Both groups share one
    // selection index space (nonFileItems, then fileItems) so arrow-key
    // navigation flows continuously from one section into the other.
    private var nonFileItems: [ClipboardItem] { viewModel.items.filter { !$0.isFile } }
    private var fileItems: [ClipboardItem] { viewModel.items.filter { $0.isFile } }

    private var combinedItems: [ClipboardItem] { nonFileItems + fileItems }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(nonFileItems.enumerated()), id: \.element.uuid) { index, item in
                        row(item: item, index: index)
                    }

                    if !fileItems.isEmpty {
                        SectionDivider()
                        Text("Files")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)

                        ForEach(Array(fileItems.enumerated()), id: \.element.uuid) { offset, item in
                            row(item: item, index: nonFileItems.count + offset)
                        }
                    }
                }
                .padding(6)
            }
            .onChange(of: selectedIndex) { _, newValue in
                guard combinedItems.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(combinedItems[newValue].uuid, anchor: nil)
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
        let count = nonFileItems.count + fileItems.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }

    private func selectCurrent() {
        let combined = nonFileItems + fileItems
        guard combined.indices.contains(selectedIndex) else { return }
        onPaste(combined[selectedIndex])
    }
}

private struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.25))
            .frame(height: 1.5)
            .padding(.vertical, 6)
    }
}
