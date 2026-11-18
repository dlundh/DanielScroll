// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DanielScroll",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DanielScroll",
            path: "Sources/DanielScroll"
        )
    ],
    swiftLanguageVersions: [.v5]
)
