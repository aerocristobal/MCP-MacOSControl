import Foundation
import MCP

public enum AppleScriptModule: ToolModule {

    /// Process-wide audit recorder. STORY-006 shipped an in-memory v1;
    /// STORY-024 made this a swappable seam — Server.swift replaces it
    /// at startup with a chained, persistent `AuditRecorder` wired to
    /// AuditStorage + AuditRemoteSink. Tests and dev paths can leave
    /// the default InMemoryAuditRecorder in place.
    public nonisolated(unsafe) static var auditor: AuditRecording = InMemoryAuditRecorder()

    public static var tools: [Tool] {
        [
            Tool(
                name: "click_menu_item",
                description: """
                Activate an application menu item by hierarchical name path (e.g. \
                ["Format", "Font", "Bold"]). Locates and clicks the item via System Events. \
                LOCALE-SENSITIVE: callers must pass each component in the user's current macOS \
                locale — the tool does not translate menu names. Trailing ellipsis (… or ...) \
                and surrounding whitespace are normalized away. By default the target app is \
                briefly activated to receive the click; pass do_not_activate=true to skip the \
                activation step. Returns code "menu_item_disabled" when the resolved item is \
                present but disabled, and "menu_item_not_found" with an alphabetical \
                "alternatives" list of items at the failing level otherwise. NOTE: a not-found \
                response triggers a second AppleScript call to enumerate alternatives, so a \
                single failed invocation produces TWO audit records. application defaults to \
                the frontmost app when omitted. Path depth is capped at 6 components.
                """,
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "application": [
                            "type": "string",
                            "description": "Target application name (e.g. \"TextEdit\"). Optional — defaults to the frontmost application's localized name. Locale-sensitive."
                        ],
                        "path": [
                            "type": "array",
                            "description": "Hierarchical menu path from menu bar inward, e.g. [\"Format\", \"Font\", \"Bold\"]. Required. Length 1–6. Locale-sensitive: each component must match the localized menu/item name. Trailing ellipsis and whitespace are normalized."
                        ],
                        "do_not_activate": [
                            "type": "boolean",
                            "description": "When true, skips the `tell application X to activate` preamble. Default false (the target app is activated, briefly stealing focus).",
                            "default": false
                        ]
                    ],
                    required: ["path"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "run_applescript",
                description: """
                Execute an AppleScript source string via /usr/bin/osascript and return structured \
                results. Use this for app-dictionary automation (Finder, Mail, Safari, TextEdit, \
                Numbers, Script Editor, etc.) where AX semantic actions are insufficient — e.g., \
                "tell Mail to send", "ask Finder for selected files", "set value of front document". \
                AppleScript only — JXA (do JavaScript / -l JavaScript) is NOT supported. \
                SECURITY: scripts containing `do shell script`, `do JavaScript`, `load script`, \
                `tell application "System Events"`, or path-traversal patterns are rejected before \
                execution. Each invocation is audit-logged. Target apps must have macOS Automation \
                permission granted; missing permission returns a structured error naming the app. \
                Output is capped at 1 MB (truncated:true flag set when reached). \
                STORY-024: invocations are audit-logged with a SHA-256 fingerprint of the script \
                source — never the verbatim source, which is treated as sensitive. The audit log \
                is hash-chained, retained per MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS (default 365), \
                and shipped off-host to the configured sink (default OSLog subsystem \
                com.mcp.macos-control.audit).
                """,
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "script": [
                            "type": "string",
                            "description": "AppleScript source to execute. Required. Pass a single source string; multi-line scripts are supported via embedded newlines."
                        ],
                        "timeout_seconds": [
                            "type": "integer",
                            "description": "Maximum execution time in seconds. Default 30, minimum 1, maximum 300. The osascript process is terminated when the timeout elapses.",
                            "default": 30
                        ]
                    ],
                    required: ["script"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            )
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        switch params.name {
        case "run_applescript":
            let tool = RunAppleScriptTool(
                filter: AppleScriptSecurityFilter(),
                permissionChecker: AutomationPermissionChecker(),
                executor: AppleScriptExecutor(),
                audit: auditor
            )
            return try await tool.execute(params)
        case "click_menu_item":
            let backend = AppleScriptMenuClickBackend(
                executor: AppleScriptExecutor(),
                resolver: MenuPathResolver(),
                audit: auditor
            )
            let tool = ClickMenuItemTool(
                backend: backend,
                normalizer: MenuItemNormalizer()
            )
            return try await tool.execute(params)
        default:
            return nil
        }
    }
}
