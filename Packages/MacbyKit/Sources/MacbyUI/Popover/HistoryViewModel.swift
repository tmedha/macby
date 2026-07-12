import Combine
import Foundation
import GRDB
import MacbyCore
import MacbyPersistence

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public var items: [ClipboardItem] = []
    @Published public var searchText: String = "" {
        didSet { scheduleSearch() }
    }

    private let historyStore: HistoryStore
    private var observationCancellable: DatabaseCancellable?
    private var searchDebounceTask: Task<Void, Never>?

    public init(historyStore: HistoryStore, dbQueue: DatabaseQueue) {
        self.historyStore = historyStore
        let observation = historyStore.observeRecentItems()
        observationCancellable = observation.start(
            in: dbQueue,
            onError: { error in NSLog("HistoryViewModel observation error: \(error)") },
            onChange: { [weak self] items in
                guard let self, self.searchText.isEmpty else { return }
                self.items = items
            }
        )
    }

    private func scheduleSearch() {
        searchDebounceTask?.cancel()
        let query = searchText
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, let self else { return }
            let results = (try? self.historyStore.search(query)) ?? []
            self.items = results
        }
    }

    public func togglePin(_ item: ClipboardItem) {
        try? historyStore.setPinned(!item.isPinned, uuid: item.uuid)
    }

    public func delete(_ item: ClipboardItem) {
        try? historyStore.delete(uuid: item.uuid)
    }
}
