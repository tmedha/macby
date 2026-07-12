import Foundation
import GRDB
import MacbyCore

/// GRDB-mapped row for `clipboardItem`. Kept separate from `MacbyCore.ClipboardItem`
/// so the core model stays free of persistence-framework imports; this struct only
/// exists to bridge SQLite storage (e.g. JSON-encoding `fileURLs`) to the domain model.
struct ClipboardItemRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clipboardItem"

    var id: Int64?
    var uuid: String
    var contentType: String
    var createdAt: Date

    var textPreview: String?
    var fullTextPath: String?
    var imageThumbnailPath: String?
    var imageFullPath: String?
    var fileURLs: String? // JSON-encoded [String]

    var contentHash: String
    var sourceAppBundleID: String?
    var sourceAppName: String?

    var isPinned: Bool
    var isSensitive: Bool
    var sensitivityKind: String?
    var otpAutoClearAt: Date?
    var otpCleared: Bool

    var savedToFolderPath: String?
    var savedFolderCategory: String?

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    init(from item: ClipboardItem) {
        id = item.id
        uuid = item.uuid
        contentType = item.contentType.rawValue
        createdAt = item.createdAt
        textPreview = item.textPreview
        fullTextPath = item.fullTextPath
        imageThumbnailPath = item.imageThumbnailPath
        imageFullPath = item.imageFullPath
        fileURLs = item.fileURLs.flatMap { urls -> String? in
            guard let data = try? JSONEncoder().encode(urls) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        contentHash = item.contentHash
        sourceAppBundleID = item.sourceAppBundleID
        sourceAppName = item.sourceAppName
        isPinned = item.isPinned
        isSensitive = item.isSensitive
        sensitivityKind = item.sensitivityKind?.rawValue
        otpAutoClearAt = item.otpAutoClearAt
        otpCleared = item.otpCleared
        savedToFolderPath = item.savedToFolderPath
        savedFolderCategory = item.savedFolderCategory
    }

    func asDomainItem() -> ClipboardItem {
        ClipboardItem(
            id: id,
            uuid: uuid,
            contentType: ContentType(rawValue: contentType) ?? .text,
            createdAt: createdAt,
            textPreview: textPreview,
            fullTextPath: fullTextPath,
            imageThumbnailPath: imageThumbnailPath,
            imageFullPath: imageFullPath,
            fileURLs: fileURLs.flatMap { json in
                json.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) }
            },
            contentHash: contentHash,
            sourceAppBundleID: sourceAppBundleID,
            sourceAppName: sourceAppName,
            isPinned: isPinned,
            isSensitive: isSensitive,
            sensitivityKind: sensitivityKind.flatMap { SensitivityKind(rawValue: $0) },
            otpAutoClearAt: otpAutoClearAt,
            otpCleared: otpCleared,
            savedToFolderPath: savedToFolderPath,
            savedFolderCategory: savedFolderCategory
        )
    }
}
