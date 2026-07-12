import Foundation
import Testing
import MacbyCore
import GRDB
@testable import MacbyPersistence

@Suite struct HistoryStoreTests {
    private func makeStore() throws -> HistoryStore {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        return HistoryStore(dbQueue: dbQueue, maxHistoryItemCount: 5)
    }

    @Test func captureAssignsAutoIncrementedID() throws {
        let store = try makeStore()
        let item = ClipboardItem(
            contentType: .text,
            textPreview: "hello",
            contentHash: ContentHasher.hash(text: "hello")
        )
        let captured = try store.capture(item)
        #expect(captured.id != nil)
    }

    @Test func duplicateContentBumpsRecencyInsteadOfInserting() throws {
        let store = try makeStore()
        let hash = ContentHasher.hash(text: "dup")
        let first = try store.capture(ClipboardItem(contentType: .text, textPreview: "dup", contentHash: hash))
        let second = try store.capture(ClipboardItem(contentType: .text, textPreview: "dup", contentHash: hash))
        #expect(first.id == second.id)
    }

    @Test func pruningKeepsOnlyMostRecentUnpinnedItems() throws {
        let store = try makeStore()
        for i in 0..<10 {
            _ = try store.capture(ClipboardItem(
                contentType: .text,
                textPreview: "item-\(i)",
                contentHash: ContentHasher.hash(text: "item-\(i)")
            ))
        }
        let remaining = try store.search("")
        #expect(remaining.count == 5)
    }

    @Test func bumpToTopMovesItemAheadOfNewerItems() throws {
        let store = try makeStore()
        let first = try store.capture(ClipboardItem(contentType: .text, textPreview: "first", contentHash: ContentHasher.hash(text: "first")))
        _ = try store.capture(ClipboardItem(contentType: .text, textPreview: "second", contentHash: ContentHasher.hash(text: "second")))
        _ = try store.capture(ClipboardItem(contentType: .text, textPreview: "third", contentHash: ContentHasher.hash(text: "third")))

        try store.bumpToTop(uuid: first.uuid)

        let ordered = try store.search("")
        #expect(ordered.first?.uuid == first.uuid)
    }

    @Test func pinnedItemsSurvivePruning() throws {
        let store = try makeStore()
        let pinned = try store.capture(ClipboardItem(contentType: .text, textPreview: "keep-me", contentHash: ContentHasher.hash(text: "keep-me")))
        try store.setPinned(true, uuid: pinned.uuid)
        for i in 0..<10 {
            _ = try store.capture(ClipboardItem(
                contentType: .text,
                textPreview: "item-\(i)",
                contentHash: ContentHasher.hash(text: "item-\(i)")
            ))
        }
        let remaining = try store.search("")
        #expect(remaining.contains { $0.uuid == pinned.uuid })
    }
}
