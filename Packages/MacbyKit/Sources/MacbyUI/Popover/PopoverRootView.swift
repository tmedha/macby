import SwiftUI
import MacbyCore

public struct PopoverRootView: View {
    @ObservedObject var viewModel: HistoryViewModel
    let onPaste: (ClipboardItem) -> Void
    let onClose: () -> Void

    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    public init(
        viewModel: HistoryViewModel,
        onPaste: @escaping (ClipboardItem) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onPaste = onPaste
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            list
        }
        .frame(width: 360, height: 420)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
        .onChange(of: viewModel.items) { _, _ in selectedIndex = 0 }
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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.uuid) { index, item in
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
            }
            .padding(6)
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
