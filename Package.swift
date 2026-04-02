// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MCP-MacOSControl",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "mcp-macos-control",
            targets: ["MCP-MacOSControl"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.0")
    ],
    targets: [
        .target(
            name: "MacOSControlLib",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/MacOSControlLib"
        ),
        .executableTarget(
            name: "MCP-MacOSControl",
            dependencies: [
                "MacOSControlLib",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/MCP-MacOSControl"
        ),
        .testTarget(
            name: "MCP-MacOSControlTests",
            dependencies: [
                "MacOSControlLib",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Tests/MCP-MacOSControlTests"
        )
    ]
)
