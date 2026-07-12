import Foundation
import GRDB
import MacbyCore

public final class HistoryStore: @unchecked Sendable {
    private let dbQueue: DatabaseQueue
    public var maxHistoryItemCount: Int

    public init(dbQueue: DatabaseQueue, maxHistoryItemCount: Int = 500) {
        self.dbQueue = dbQueue
        self.maxHistoryItemCount = maxHistoryItemCount
    }

    /// Inserts a new item, or — if an item with the same content hash already
    /// exists — bumps its `createdAt` to now instead of creating a duplicate row.
    @discardableResult
    public func capture(_ item: ClipboardItem) throws -> ClipboardItem {
        try dbQueue.write { db in
            if var existing = try ClipboardItemRecord
                .filter(Column("contentHash") == item.contentHash)
                .fetchOne(db)
            {
                existing.createdAt = item.createdAt
                // A re-copied identical OTP (e.g. a resent code) should become
                // eligible for auto-clear again rather than staying marked as
                // already-cleared from its prior appearance.
                if item.sensitivityKind == .otp {
                    existing.sensitivityKind = SensitivityKind.otp.rawValue
                    existing.otpCleared = false
                }
                try existing.update(db)
                try self.pruneIfNeeded(db)
                return existing.asDomainItem()
            }

            var record = ClipboardItemRecord(from: item)
            try record.insert(db)
            try self.pruneIfNeeded(db)
            return record.asDomainItem()
        }
    }

    /// Live-observed feed of the most recent items, newest first, capped at `limit`
    /// so the UI never has to hold the entire history table in memory.
    public func observeRecentItems(limit: Int = 200) -> ValueObservation<ValueReducers.Fetch<[ClipboardItem]>> {
        ValueObservation.tracking { db in
            try ClipboardItemRecord
                .order(Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
                .map { $0.asDomainItem() }
        }
    }

    public func search(_ query: String, limit: Int = 200) throws -> [ClipboardItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try dbQueue.read { db in
                try ClipboardItemRecord
                    .order(Column("createdAt").desc)
                    .limit(limit)
                    .fetchAll(db)
                    .map { $0.asDomainItem() }
            }
        }
        guard let pattern = FTS5Pattern(matchingAllPrefixesIn: query) else { return [] }
        return try dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(
                db,
                sql: """
                SELECT clipboardItem.* FROM clipboardItem
                JOIN clipboardItem_fts ON clipboardItem_fts.rowid = clipboardItem.id
                WHERE clipboardItem_fts MATCH ?
                ORDER BY clipboardItem.createdAt DESC
                LIMIT ?
                """,
                arguments: [pattern, limit]
            ).map { $0.asDomainItem() }
        }
    }

    /// The most recent OTP-flagged item that hasn't yet been auto-cleared.
    /// Used by `OTPAutoClearService` to decide whether a detected paste (or an
    /// elapsed timeout) still applies to what's currently on the pasteboard.
    public func mostRecentUnclearedOTPItem() throws -> ClipboardItem? {
        try dbQueue.read { db in
            try ClipboardItemRecord
                .filter(Column("sensitivityKind") == SensitivityKind.otp.rawValue)
                .filter(Column("otpCleared") == false)
                .order(Column("createdAt").desc)
                .fetchOne(db)?
                .asDomainItem()
        }
    }

    public func markOTPCleared(uuid: String) throws {
        try dbQueue.write { db in
            if var record = try ClipboardItemRecord.filter(Column("uuid") == uuid).fetchOne(db) {
                record.otpCleared = true
                try record.update(db)
            }
        }
    }

    public func setPinned(_ pinned: Bool, uuid: String) throws {
        try dbQueue.write { db in
            if var record = try ClipboardItemRecord.filter(Column("uuid") == uuid).fetchOne(db) {
                record.isPinned = pinned
                try record.update(db)
            }
        }
    }

    public func delete(uuid: String) throws {
        _ = try dbQueue.write { db in
            try ClipboardItemRecord.filter(Column("uuid") == uuid).deleteAll(db)
        }
    }

    /// Deletes all non-pinned items. Pass `includingPinned: true` to wipe everything.
    public func clearHistory(includingPinned: Bool = false) throws {
        _ = try dbQueue.write { db in
            if includingPinned {
                try ClipboardItemRecord.deleteAll(db)
            } else {
                try ClipboardItemRecord.filter(Column("isPinned") == false).deleteAll(db)
            }
        }
    }

    /// Drops oldest, unpinned rows past `maxHistoryItemCount`. Sensitive/OTP items
    /// are pruned like everything else — silently retaining flagged-sensitive data
    /// past the user's configured history length would itself be a privacy risk.
    private func pruneIfNeeded(_ db: GRDB.Database) throws {
        let unpinnedCount = try ClipboardItemRecord
            .filter(Column("isPinned") == false)
            .fetchCount(db)
        let overflow = unpinnedCount - maxHistoryItemCount
        guard overflow > 0 else { return }

        let idsToDelete = try ClipboardItemRecord
            .filter(Column("isPinned") == false)
            .order(Column("createdAt").asc)
            .limit(overflow)
            .fetchAll(db)
            .compactMap(\.id)
        try ClipboardItemRecord.filter(keys: idsToDelete).deleteAll(db)
    }
}
