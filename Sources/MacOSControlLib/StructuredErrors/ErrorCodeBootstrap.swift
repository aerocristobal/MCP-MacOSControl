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
            description: "A wait_for_text / wait_for_ui_event / wait_for_app_event predicate did not become true before the timeout elapsed. STORY-008 wait_for_ui_event surfaces the AX notification name; STORY-018 wait_for_app_event surfaces the app event name and bundle_id filter; both include elapsed time.",
            detailsSchema: [
                "notification": "string",
                "event": "string",
                "bundle_id_filter": "string",
                "elapsed_seconds": "number"
            ]
        )
        try registry.register(
            code: "state_condition_not_met",
            description: "Expected post-condition state was not observed. STORY-009 wait_for_element_state polled until its timeout without the element reaching the requested state; details carry the parsed condition, the last serialized element state (or absence), elapsed seconds, and the number of polls performed.",
            detailsSchema: [
                "condition": "string",
                "current_state": "object",
                "elapsed_seconds": "number",
                "polls_performed": "number"
            ]
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

        // MARK: - STORY-008 — Wait For UI Event tool

        try registry.register(
            code: "target_application_terminated",
            description: "The application named in a wait_for_ui_event subscription terminated before the notification fired. The error details carry the terminated app's pid and (when known) bundle identifier.",
            detailsSchema: [
                "pid": "number",
                "bundle_identifier": "string"
            ]
        )
        try registry.register(
            code: "unsupported_notification",
            description: "The notification name passed to wait_for_ui_event is not in the closed supported set. The error details echo the rejected name and the full supported list.",
            detailsSchema: [
                "notification": "string",
                "supported_notifications": "array"
            ]
        )
        try registry.register(
            code: "timeout_exceeds_maximum",
            description: "The requested wait_for_ui_event timeout exceeds the server's hard cap of 300 seconds. Use an MCP Resources subscription for longer watches.",
            detailsSchema: [
                "requested_seconds": "number",
                "maximum_seconds": "number"
            ]
        )

        // MARK: - Prompts (STORY-017)

        try registry.register(
            code: "missing_required_argument",
            description: "A prompts/get request omitted an argument declared as required by the prompt definition, or the prompt body referenced a placeholder for which no argument was supplied.",
            detailsSchema: [
                "argument": "string"
            ]
        )
        try registry.register(
            code: "prompt_not_found",
            description: "A prompts/get request named a prompt that is not registered with the server. The error details include the list of available prompt names.",
            detailsSchema: [
                "available": "array"
            ]
        )

        // MARK: - STORY-009 — Element State Polling tool
        // (state_condition_not_met is registered above with the broader codes.)

        try registry.register(
            code: "invalid_condition_expression",
            description: "The condition passed to wait_for_element_state could not be parsed. The error details echo the rejected expression and the closed set of supported fields and operators.",
            detailsSchema: [
                "expression": "string",
                "supported_fields": "array",
                "supported_operators": "array"
            ]
        )

        // MARK: - STORY-018 — Wait For Application Lifecycle Event tool

        try registry.register(
            code: "unsupported_app_event",
            description: "The event name passed to wait_for_app_event is not in the closed supported set. The error details echo the rejected name and the full supported list.",
            detailsSchema: [
                "event": "string",
                "supported_events": "array"
            ]
        )
        try registry.register(
            code: "invalid_bundle_identifier",
            description: "The bundle_identifier passed to wait_for_app_event is not a valid Apple reverse-DNS bundle identifier. The error details echo the rejected value and the expected pattern.",
            detailsSchema: [
                "bundle_identifier": "string",
                "bundle_identifier_pattern": "string"
            ]
        )

        // MARK: - STORY-019 — Per-Application Capability Registry

        try registry.register(
            code: "invalid_capability_registry_override",
            description: "The user app-capabilities override file could not be parsed. Malformed entries are skipped and the server starts using only the shipped defaults. The error details identify the offending file path and, when available, the line number.",
            detailsSchema: [
                "file_path": "string",
                "line": "number"
            ]
        )

        // MARK: - STORY-010 — Agent Interaction Hierarchy Router (smart_interact)

        try registry.register(
            code: "all_layers_failed",
            description: "smart_interact exhausted every eligible interaction layer (AX semantic, AppleScript, hit-test, coordinate) without a success. The error details carry the full ordered decision_log of attempts and skip/fail reasons plus retry_suggestions.",
            detailsSchema: [
                "decision_log": "array",
                "retry_suggestions": "array"
            ]
        )
        try registry.register(
            code: "unsupported_intent",
            description: "The intent passed to smart_interact is not in the supported set. v1 supports click and type. The error details echo the rejected intent and the full supported list.",
            detailsSchema: [
                "intent": "string",
                "supported": "array"
            ]
        )
        try registry.register(
            code: "missing_required_field",
            description: "A required smart_interact input field was absent (intent is always required; value is required when intent=type). The error details name the missing field.",
            detailsSchema: [
                "field": "string"
            ]
        )
    }
}
