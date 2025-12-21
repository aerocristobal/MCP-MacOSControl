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
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "MCP-MacOSControl",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources"
        )
    ]
)
