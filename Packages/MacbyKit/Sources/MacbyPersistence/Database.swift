import Foundation
import GRDB

public enum Database {
    public static func makeQueue(at url: URL) throws -> DatabaseQueue {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let queue = try DatabaseQueue(path: url.path)
        var migrator = DatabaseMigrator()
        registerMigrations(&migrator)
        try migrator.migrate(queue)
        return queue
    }

    public static var defaultStoreURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return appSupport
            .appendingPathComponent("Macby", isDirectory: true)
            .appendingPathComponent("macby.sqlite")
    }
}
