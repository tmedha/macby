import GRDB

func registerMigrations(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("v1_initial") { db in
        try db.create(table: "clipboardItem") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("uuid", .text).notNull().unique()
            t.column("contentType", .text).notNull()
            t.column("createdAt", .datetime).notNull()

            t.column("textPreview", .text)
            t.column("fullTextPath", .text)
            t.column("imageThumbnailPath", .text)
            t.column("imageFullPath", .text)
            t.column("fileURLs", .text) // JSON-encoded [String]

            t.column("contentHash", .text).notNull()
            t.column("sourceAppBundleID", .text)
            t.column("sourceAppName", .text)

            t.column("isPinned", .boolean).notNull().defaults(to: false)
            t.column("isSensitive", .boolean).notNull().defaults(to: false)
            t.column("sensitivityKind", .text)
            t.column("otpAutoClearAt", .datetime)
            t.column("otpCleared", .boolean).notNull().defaults(to: false)

            t.column("savedToFolderPath", .text)
            t.column("savedFolderCategory", .text)
        }
        try db.create(index: "idx_clipboardItem_createdAt", on: "clipboardItem", columns: ["createdAt"])
        try db.create(index: "idx_clipboardItem_contentHash", on: "clipboardItem", columns: ["contentHash"])

        try db.create(virtualTable: "clipboardItem_fts", using: FTS5()) { t in
            t.synchronize(withTable: "clipboardItem")
            t.column("textPreview")
            t.column("sourceAppName")
        }
    }
}
