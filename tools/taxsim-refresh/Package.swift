// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "taxsim-refresh",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "taxsim-refresh",
            path: "Sources/taxsim-refresh"
        )
    ]
)
