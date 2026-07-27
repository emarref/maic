// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "maic",
    platforms: [
        .macOS("26.0"),
    ],
    targets: [
        // Pure, I/O-free logic — importable and testable anywhere.
        .target(
            name: "MaicCore",
            path: "Sources/MaicCore"
        ),
        // The CLI itself: argument handling, the on-device model, and I/O.
        .executableTarget(
            name: "maic",
            dependencies: ["MaicCore"],
            path: "Sources/maic"
        ),
        // Test harness, run with `swift run maicTests`. A plain executable
        // rather than a testTarget: `swift test` needs full Xcode, but this
        // runs under Command Line Tools and on CI alike.
        .executableTarget(
            name: "maicTests",
            dependencies: ["MaicCore"],
            path: "Tests/maicTests"
        ),
    ]
)
