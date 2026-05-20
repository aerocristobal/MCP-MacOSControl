import Foundation
import MCP

/// Static catalog of MCP `Resource` records advertised by `resources/list`.
/// Descriptions reference `AXNodeSerializer.schemaVersion` dynamically so a
/// future serializer bump (e.g. STORY-015 → v3 → vN) automatically updates
/// the advertised description without a manual edit here.
public enum MCPResourceCatalog {

    public static var allResources: [Resource] {
        [
            Resource(
                name: "active-application",
                uri: ResourceURIs.activeApplication,
                description: """
                Identity of the macOS application currently in the foreground (NSWorkspace.frontmostApplication). \
                Returns name, localized display_name, bundle_identifier, and pid as JSON. Subscribe for a \
                notifications/resources/updated message when the user switches applications. Returns a \
                NO_FRONTMOST_APPLICATION error when the system is in Mission Control, the login screen, or \
                another state without a foreground app.
                """,
                mimeType: "application/json"
            ),
            Resource(
                name: "active-window-tree",
                uri: ResourceURIs.activeWindowTree,
                description: """
                Accessibility tree of the frontmost application's active window. Same per-node shape as the \
                accessibility_tree tool (schema_version \(AXNodeSerializer.schemaVersion)). max_depth defaults \
                to 6 — override per request by appending ?max_depth=N (clamped to [1, 50]). Reads within 100ms \
                of each other return a cached snapshot to bound AX-walk cost under polling. Subscribe for a \
                notifications/resources/updated message when the active window changes (debounced 100ms to \
                suppress Cmd-Tab flurries). Returns ACCESSIBILITY_PERMISSION_REQUIRED when the host process \
                has not been granted Accessibility permission in System Settings.
                """,
                mimeType: "application/json"
            ),
            Resource(
                name: "capability-registry",
                uri: ResourceURIs.capabilityRegistryContents,
                description: """
                STORY-019 per-application interaction-layer capability registry. Returns a JSON \
                document { schema_version, entries[] } where each entry records bundle_id and \
                boolean ax_supported / applescript_supported / hit_test_supported flags plus a \
                source field ("defaults" or "user_override"). Operators can read this to see why \
                smart routing skipped a layer for a given app. Static after server startup; user \
                overrides live in ~/Library/Application Support/mcp-macos-control/app-overrides.json \
                (redirect via MCP_MACOS_CONTROL_OVERRIDES_PATH).
                """,
                mimeType: "application/json"
            )
        ]
    }
}
