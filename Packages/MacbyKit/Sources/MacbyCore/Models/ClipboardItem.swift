import Foundation

/// A single captured clipboard entry. Large payloads (images, oversized text) are
/// never stored inline here — only paths into the on-disk blob store — so this
/// struct stays cheap to fetch, diff, and hold in memory in bulk.
public struct ClipboardItem: Codable, Identifiable, Equatable, Sendable {
    public var id: Int64?
    public var uuid: String
    public var contentType: ContentType
    public var createdAt: Date

    public var textPreview: String?
    public var fullTextPath: String?
    public var imageThumbnailPath: String?
    public var imageFullPath: String?
    public var fileURLs: [String]?

    public var contentHash: String
    public var sourceAppBundleID: String?
    public var sourceAppName: String?

    public var isPinned: Bool
    public var isSensitive: Bool
    public var sensitivityKind: SensitivityKind?

    public var savedToFolderPath: String?
    public var savedFolderCategory: String?

    public init(
        id: Int64? = nil,
        uuid: String = UUID().uuidString,
        contentType: ContentType,
        createdAt: Date = Date(),
        textPreview: String? = nil,
        fullTextPath: String? = nil,
        imageThumbnailPath: String? = nil,
        imageFullPath: String? = nil,
        fileURLs: [String]? = nil,
        contentHash: String,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        isPinned: Bool = false,
        isSensitive: Bool = false,
        sensitivityKind: SensitivityKind? = nil,
        savedToFolderPath: String? = nil,
        savedFolderCategory: String? = nil
    ) {
        self.id = id
        self.uuid = uuid
        self.contentType = contentType
        self.createdAt = createdAt
        self.textPreview = textPreview
        self.fullTextPath = fullTextPath
        self.imageThumbnailPath = imageThumbnailPath
        self.imageFullPath = imageFullPath
        self.fileURLs = fileURLs
        self.contentHash = contentHash
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.isPinned = isPinned
        self.isSensitive = isSensitive
        self.sensitivityKind = sensitivityKind
        self.savedToFolderPath = savedToFolderPath
        self.savedFolderCategory = savedFolderCategory
    }

    public var isFile: Bool { contentType == .fileList }
}
