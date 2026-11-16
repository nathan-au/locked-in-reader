// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LockedInReader",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LockedInReader",
            path: "Sources/LockedInReader"
        )
    ],
    swiftLanguageVersions: [.v5]
)
