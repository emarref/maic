// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "maic",
    platforms: [
        .macOS("26.0"),
    ],
    targets: [
        .executableTarget(
            name: "maic",
            path: "Sources/maic"
        ),
    ]
)
