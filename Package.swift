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
        ),
        // STORY-037 — CLI executables for the POA&M and Assessment Results
        // artifacts. `oscal-emit` converts AuditRecord JSONL into OSCAL
        // observations; `oscal-drift` checks SECURITY.md / POA&M / OSCAL
        // bidirectional drift.
        .executable(
            name: "oscal-emit",
            targets: ["OscalEmit"]
        ),
        .executable(
            name: "oscal-drift",
            targets: ["OscalDrift"]
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
        // STORY-022 — Compliance tooling used only by tests and the OSCAL-
        // authoring CLIs (oscal-emit, oscal-drift). Kept out of
        // MacOSControlLib so the runtime module stays focused on the MCP
        // server surface. STORY-037 added a dependency on MacOSControlLib
        // because the AuditRecord schema (the input to oscal-emit) is
        // canonical there.
        .target(
            name: "OSCALComplianceSupport",
            dependencies: ["MacOSControlLib"],
            path: "Sources/OSCALComplianceSupport"
        ),
        // STORY-037 — CLI that converts STORY-024 AuditRecord JSONL into
        // OSCAL Assessment Results observations (append-only). Lives here
        // because the AuditRecord schema is canonical in this repo.
        .executableTarget(
            name: "OscalEmit",
            dependencies: ["MacOSControlLib", "OSCALComplianceSupport"],
            path: "Sources/OscalEmit"
        ),
        // STORY-037 — CLI that checks SECURITY.md §4 ↔ POA&M and the existing
        // SECURITY.md §7/§8 ↔ component-definition.json drift. Extension of
        // the STORY-022 drift detector with POA&M coverage rules.
        .executableTarget(
            name: "OscalDrift",
            dependencies: ["OSCALComplianceSupport"],
            path: "Sources/OscalDrift"
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
                "OSCALComplianceSupport",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Tests/MCP-MacOSControlTests",
            resources: [
                .copy("Features"),
                .copy("AppCompatibilityFixtures"),
                .copy("Compliance/Fixtures")
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
