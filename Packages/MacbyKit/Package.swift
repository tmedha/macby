// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacbyKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacbyCore", targets: ["MacbyCore"]),
        .library(name: "MacbyPersistence", targets: ["MacbyPersistence"]),
        .library(name: "MacbySystem", targets: ["MacbySystem"]),
        .library(name: "MacbyUI", targets: ["MacbyUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0")
    ],
    targets: [
        .target(
            name: "MacbyCore"
        ),
        .target(
            name: "MacbyPersistence",
            dependencies: [
                "MacbyCore",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .target(
            name: "MacbySystem",
            dependencies: ["MacbyCore", "MacbyPersistence"]
        ),
        .target(
            name: "MacbyUI",
            dependencies: ["MacbyCore", "MacbyPersistence", "MacbySystem"]
        ),
        .testTarget(
            name: "MacbyCoreTests",
            dependencies: ["MacbyCore"]
        ),
        .testTarget(
            name: "MacbyPersistenceTests",
            dependencies: ["MacbyPersistence"]
        ),
        .testTarget(
            name: "MacbySystemTests",
            dependencies: ["MacbySystem"]
        )
    ]
)
