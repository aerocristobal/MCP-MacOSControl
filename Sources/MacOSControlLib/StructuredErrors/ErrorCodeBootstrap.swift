import Foundation

public enum ErrorCodeBootstrap {

    /// Registers every error code emitted anywhere in the server. Called once at startup.
    /// Idempotent for tests via `registry.reset()` then re-register.
    public static func register(into registry: ErrorCodeRegistry = .shared) throws {
        // MARK: - MCPError cases (16)

        try registry.register(
            code: "permission_denied",
            description: "A required system permission was denied. Generic permission failure; see accessibility_permission_required or automation_permission_required for kind-specific variants.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "window_not_found",
            description: "Requested window or application could not be located.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "mirroring_not_running",
            description: "iPhone Mirroring is not running. Launch iphone_launch first.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "mirroring_not_available",
            description: "iPhone Mirroring is not available on this Mac or for this Apple ID.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "calibration_failed",
            description: "iPhone Mirroring window calibration failed; coordinates cannot be mapped reliably.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "invalid_coordinates",
            description: "Coordinates failed validation (e.g., NaN, infinity, or otherwise malformed).",
            detailsSchema: [:]
        )
        try registry.register(
            code: "input_failed",
            description: "Synthesizing a keyboard or mouse input event failed.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "mirroring_disconnected",
            description: "iPhone Mirroring connection was lost. Use iphone_reconnect to wait for recovery.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "rate_limited",
            description: "Tool invocation was rate-limited by an internal token bucket. Retry with backoff.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "timeout",
            description: "Generic operation timeout. Domain-specific variants: wait_timeout, execution_timeout.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "applescript_error",
            description: "AppleScript compilation or execution returned an error.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "execution_timeout",
            description: "An AppleScript or menu-click execution exceeded its configured timeout.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "security_policy_violation",
            description: "Input violated the server's security policy (e.g., disallowed AppleScript verb).",
            detailsSchema: [:]
        )
        try registry.register(
            code: "automation_permission_required",
            description: "Cross-application Automation (Apple Events) permission required for the named target application.",
            detailsSchema: [
                "target_application": "string",
                "recovery_hint": "string"
            ]
        )
        try registry.register(
            code: "no_frontmost_application",
            description: "No application currently has frontmost status (e.g., system is in Mission Control or the login screen).",
            detailsSchema: [:]
        )
        try registry.register(
            code: "accessibility_permission_required",
            description: "Accessibility permission required. Grant in System Settings > Privacy & Security > Accessibility.",
            detailsSchema: [
                "recovery_hint": "string",
                "system_settings_uri": "string"
            ]
        )

        // MARK: - AX errors (5)

        try registry.register(
            code: "ax_not_found",
            description: "No accessibility element matched the supplied search criteria.",
            detailsSchema: [
                "search_criteria": "string"
            ]
        )
        try registry.register(
            code: "ax_resolution_failed",
            description: "Accessibility element lookup failed at the AX layer (e.g., AX timeout, AX API error).",
            detailsSchema: [
                "underlying_code": "number"
            ]
        )
        try registry.register(
            code: "ax_element_disabled",
            description: "The resolved accessibility element is disabled and cannot accept the requested action.",
            detailsSchema: [
                "action": "string"
            ]
        )
        try registry.register(
            code: "ax_action_unsupported",
            description: "The resolved accessibility element does not support the requested AX action.",
            detailsSchema: [
                "action": "string"
            ]
        )
        try registry.register(
            code: "ax_action_failed",
            description: "Dispatching the AX action returned an error from the Accessibility API.",
            detailsSchema: [
                "action": "string",
                "underlying_code": "number"
            ]
        )
        try registry.register(
            code: "action_not_supported",
            description: "perform_ax_action discovery (no action supplied) or dispatch determined the action is not in the element's supported_actions list.",
            detailsSchema: [
                "action": "string",
                "supported_actions": "array",
                "reason": "string"
            ]
        )

        // MARK: - FindElementsError (4)

        try registry.register(
            code: "predicate_too_broad",
            description: "find_elements was called without any matching criteria. At least one of role/title/identifier/label/description must be set.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "invalid_regex",
            description: "Regex predicate failed to compile.",
            detailsSchema: [
                "field": "string"
            ]
        )
        try registry.register(
            code: "conflicting_title_predicates",
            description: "At most one of title, title_contains, title_matches may be set per call.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "conflicting_identifier_predicates",
            description: "At most one of identifier, identifier_matches may be set per call.",
            detailsSchema: [:]
        )

        // MARK: - Consumer / cross-tool codes

        try registry.register(
            code: "coordinates_out_of_bounds",
            description: "Supplied coordinates fall outside the union of all attached display bounds.",
            detailsSchema: [
                "display_bounds": "object"
            ]
        )
        try registry.register(
            code: "menu_item_not_found",
            description: "Requested menu path did not resolve to a menu item; alternatives at the failing level are included.",
            detailsSchema: [
                "alternatives": "array"
            ]
        )
        try registry.register(
            code: "menu_item_disabled",
            description: "Resolved menu item exists but is currently disabled.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "wait_timeout",
            description: "A wait_for_text / wait predicate did not become true before the timeout elapsed.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "state_condition_not_met",
            description: "Expected post-condition state was not observed after performing the action.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "invalid_input",
            description: "Tool input failed validation (missing required field, wrong type, out-of-range, etc.).",
            detailsSchema: [:]
        )
        try registry.register(
            code: "backend_error",
            description: "An underlying backend (AppleScript engine, AX bridge, etc.) returned an unrecoverable error.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "unknown_tool",
            description: "No tool matched the requested name in any registered module.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "internal_error",
            description: "An unexpected Swift error reached the MCP response boundary. The originating type is reported via swift_error_type; file paths are scrubbed.",
            detailsSchema: [
                "swift_error_type": "string"
            ]
        )

        // MARK: - Tool-specific codes used at tool boundaries

        try registry.register(
            code: "element_not_found",
            description: "Tool-boundary equivalent of ax_not_found: no accessibility element matched the supplied locator criteria.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "action_failed",
            description: "An AX action dispatched by click_element or perform_ax_action reported a generic failure not captured by ax_action_failed.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "application_not_found",
            description: "Tool could not locate the requested application by bundle id or name.",
            detailsSchema: [:]
        )
        try registry.register(
            code: "predicate_compile_failed",
            description: "find_elements predicate compilation failed before traversal began (catch-all sibling of predicate_too_broad / invalid_regex).",
            detailsSchema: [:]
        )
        try registry.register(
            code: "unknown_display_index",
            description: "element_at_position was given a display_index that does not map to an active display.",
            detailsSchema: [:]
        )
    }
}
