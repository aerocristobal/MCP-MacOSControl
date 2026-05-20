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
        ),
        // STORY-020 — App Compatibility Catalog generator. Reads
        // docs/compatibility-observations.json + the registry JSON and emits
        // docs/APP-COMPATIBILITY.md. Used by CI and maintainers locally; not
        // part of the MCP server runtime.
        .executable(
            name: "mcp-macos-control-catalog",
            targets: ["MCP-MacOSControlCatalog"]
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
            path: "Sources/MacOSControlLib",
            resources: [
                .copy("Prompts/Definitions"),
                .copy("Router/Defaults")
            ]
        ),
        .executableTarget(
            name: "MCP-MacOSControl",
            dependencies: [
                "MacOSControlLib",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/MCP-MacOSControl"
        ),
        // STORY-012 — a deliberately AX-degraded SwiftUI app used only by the
        // integration suite to force smart_interact's semantic layer to fail and
        // fall through. Version-controlled and reproducible (vs. a moving
        // third-party Electron target). Built by the integration suite; never
        // shipped in the MCP product.
        .executableTarget(
            name: "AXDegradedHarness",
            path: "Sources/AXDegradedHarness"
        ),
        // STORY-020 — Catalog generator CLI. Library does the real work; this
        // target is a thin argv parser.
        .executableTarget(
            name: "MCP-MacOSControlCatalog",
            dependencies: ["MacOSControlLib"],
            path: "Sources/MCP-MacOSControlCatalog"
        ),
        .testTarget(
            name: "MCP-MacOSControlTests",
            dependencies: [
                "MacOSControlLib",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Tests/MCP-MacOSControlTests",
            resources: [
                .copy("Features"),
                .copy("AppCompatibilityFixtures")
            ]
        ),
        // STORY-012 — End-to-End Integration Validation Suite. Separate target:
        // different requirements (real apps, accessibility permission, longer
        // timeouts, opt-in) and a different failure-investigation flow than the
        // unit suite. Skips entirely unless CI_MACOS_INTEGRATION=true, so a
        // plain `swift test` on PRs stays green.
        .testTarget(
            name: "MCP-MacOSControlIntegrationTests",
            dependencies: [
                "MacOSControlLib",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Tests/MCP-MacOSControlIntegrationTests",
            resources: [
                .copy("Features")
            ]
        )
    ]
)
