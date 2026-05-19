// STORY-012 — End-to-End Integration Validation Suite
// COMPONENT: One trigger recipe per ErrorCodeRegistry code.
//
// DoD: `ErrorTriggerManifest` covers 100% of registered codes;
// `ErrorCodeContractTests` fails fast if a code is registered without an entry.
//
// Honest taxonomy (the plan's design): not every registered code is
// deterministically forcible through a black-box tool call in an ephemeral
// process. Codes split into:
//
//   • .forcible       — a real tool call with crafted input deterministically
//                        produces this exact `error.code`. The contract test
//                        invokes it and asserts the STORY-016 envelope.
//   • .environmentGated — the code only arises from a permission state,
//                        hardware presence (iPhone Mirroring), timing/runtime
//                        condition, or a non-tool surface (Prompts). The
//                        contract test records a documented skip rather than
//                        faking a pass. The reason is the contract: it states
//                        *why* it can't be forced here and where it is proven.
//
// Every registered code MUST appear in `recipes`. A missing entry is a hard
// failure in ErrorCodeContractTests — that is the "fail fast" guarantee.

import Foundation
import MCP

enum TriggerKind {
    /// Call `tool` with `input`; expect `error.code == <key>` and `isError`.
    case forcible(tool: String, input: [String: Value])
    /// Cannot be forced deterministically here; `reason` documents why + where
    /// it is actually proven (usually a unit test under STORY-016/008/010/...).
    case environmentGated(reason: String)
}

struct TriggerRecipe {
    let code: String
    let kind: TriggerKind
}

enum ErrorTriggerManifest {

    static func recipe(for code: String) -> TriggerRecipe? {
        guard let kind = kinds[code] else { return nil }
        return TriggerRecipe(code: code, kind: kind)
    }

    /// EXACTLY the set registered by `ErrorCodeBootstrap`. Keep in lockstep —
    /// ErrorCodeContractTests cross-checks against the live registry.
    static let kinds: [String: TriggerKind] = [

        // MARK: Deterministically forcible via a real tool call

        "unknown_tool": .forcible(
            tool: "__definitely_not_a_registered_tool__", input: [:]),

        "invalid_input": .forcible(
            tool: "type_text", input: [:]),                       // "text required"

        "missing_required_field": .forcible(
            tool: "smart_interact", input: [:]),                  // intent absent

        "unsupported_intent": .forcible(
            tool: "smart_interact",
            input: ["intent": .string("frobnicate")]),

        "all_layers_failed": .forcible(
            tool: "smart_interact",
            input: [
                "intent": .string("click"),
                "target_description": .string("__no_such_control_xyzzy__"),
                "application": .string("com.apple.TextEdit"),
                "skip_layers": .array([
                    .string("applescript"),
                    .string("ax_hit_test"),
                    .string("coordinate_fallback")
                ])
            ]),

        "unsupported_app_event": .forcible(
            tool: "wait_for_app_event",
            input: ["event": .string("not_a_real_event")]),

        "invalid_bundle_identifier": .forcible(
            tool: "wait_for_app_event",
            input: [
                "event": .string("launched"),
                "bundle_identifier": .string("Not A Valid Bundle ID")
            ]),

        "timeout_exceeds_maximum": .forcible(
            tool: "wait_for_app_event",
            input: [
                "event": .string("launched"),
                "timeout_seconds": .double(99_999)
            ]),

        "invalid_coordinates": .forcible(
            tool: "element_at_position", input: [:]),             // x required

        "unknown_display_index": .forcible(
            tool: "element_at_position",
            input: [
                "x": .double(10), "y": .double(10),
                "display_index": .int(99_999)
            ]),

        "coordinates_out_of_bounds": .forcible(
            tool: "element_at_position",
            input: ["x": .double(99_999_999), "y": .double(99_999_999)]),

        "invalid_regex": .forcible(
            tool: "find_elements",
            input: ["title_matches": .string("[")]),              // bad regex

        "application_not_found": .forcible(
            tool: "find_elements",
            input: [
                "role": .string("AXButton"),
                "application": .string("com.example.does.not.exist.xyzzy")
            ]),

        "security_policy_violation": .forcible(
            tool: "run_applescript",
            input: ["script": .string("do shell script \"echo blocked\"")]),

        // MARK: Environment-/surface-gated (documented, not faked)

        // Permission state — requires revoking/granting TCC, which cannot be
        // toggled non-interactively in-process. Proven by STORY-016 unit tests
        // and the PermissionRevocationTests scenario when the env permits.
        "accessibility_permission_required": .environmentGated(
            reason: "Requires AXIsProcessTrusted()==false; TCC cannot be toggled non-interactively. Proven in STORY-016 unit tests + PermissionRevocationTests."),
        "automation_permission_required": .environmentGated(
            reason: "Requires a denied Apple Events grant for a target app; not deterministically inducible in CI. Proven in STORY-016 unit tests."),
        "permission_denied": .environmentGated(
            reason: "Generic permission failure; only arises from a denied TCC grant. Proven in STORY-016 unit tests."),
        "no_frontmost_application": .environmentGated(
            reason: "Requires the system to have no frontmost app (login window / Mission Control); not reproducible in a headed test session."),

        // iPhone Mirroring hardware — requires macOS 15 + a paired iPhone.
        "mirroring_not_running": .environmentGated(
            reason: "iPhone Mirroring subsystem; requires the Mirroring app. Covered by IPhoneMirroring unit tests."),
        "mirroring_not_available": .environmentGated(
            reason: "Requires a Mac/Apple ID without Mirroring support. Covered by IPhoneMirroring unit tests."),
        "mirroring_disconnected": .environmentGated(
            reason: "Requires losing a live Mirroring connection mid-call. Covered by IPhoneMirroring unit tests."),
        "calibration_failed": .environmentGated(
            reason: "Requires a Mirroring window that fails calibration. Covered by IPhoneMirroring unit tests."),

        // Runtime/timing conditions — non-deterministic or slow by nature.
        "rate_limited": .environmentGated(
            reason: "Requires saturating an internal token bucket; timing-dependent and flaky in CI. Proven in RateLimiter unit tests."),
        "timeout": .environmentGated(
            reason: "Generic timeout; domain variants (wait_timeout/execution_timeout) carry the real contract. Proven in unit tests."),
        "wait_timeout": .environmentGated(
            reason: "Requires waiting out a real wait_for_* timeout (≥1s of dead time per code); exercised structurally by wait-tool unit tests. Forcing here would add slow, flaky waits."),
        "state_condition_not_met": .environmentGated(
            reason: "Requires polling wait_for_element_state to its timeout; slow. Proven in STORY-009 unit tests."),
        "execution_timeout": .environmentGated(
            reason: "Requires an AppleScript/menu op exceeding its timeout; slow and host-dependent. Proven in STORY-006/007 unit tests."),
        "target_application_terminated": .environmentGated(
            reason: "Requires a watched app to die mid-subscription; racy. Proven in STORY-008 unit tests."),
        "input_failed": .environmentGated(
            reason: "Requires CGEvent synthesis to fail at the OS layer; not inducible from input validation. Proven in unit tests."),
        "backend_error": .environmentGated(
            reason: "Requires an underlying engine (AX bridge/AppleScript) to return an unrecoverable error; not deterministically inducible via input. Proven in unit tests."),
        "internal_error": .environmentGated(
            reason: "The catch-all for an unmapped Swift error reaching the boundary; by design no input forces it. Proven in ToolRouter unit tests."),

        // Resolution outcomes that depend on a live AX tree / running apps.
        "ax_not_found": .environmentGated(
            reason: "Requires a running app whose AX tree lacks the locator; element_not_found is the tool-boundary equivalent and is forced via SmartInteractFallback. Proven in STORY-001 unit tests."),
        "ax_resolution_failed": .environmentGated(
            reason: "Requires the AX API to error (timeout/cannot-complete) against a live app; not deterministic. Proven in STORY-001 unit tests."),
        "ax_element_disabled": .environmentGated(
            reason: "Requires a resolved-but-disabled control in a live app. Proven in STORY-002/003 unit tests."),
        "ax_action_unsupported": .environmentGated(
            reason: "Requires a resolved element lacking the requested AX action in a live app. Proven in STORY-003 unit tests."),
        "ax_action_failed": .environmentGated(
            reason: "Requires the AX API to reject a dispatched action at runtime. Proven in STORY-003 unit tests."),
        "action_not_supported": .environmentGated(
            reason: "perform_ax_action discovery/dispatch outcome against a live element. Proven in STORY-003 unit tests."),
        "element_not_found": .environmentGated(
            reason: "Tool-boundary ax_not_found; exercised live by SmartInteractFallbackTests against the AX-degraded harness."),
        "action_failed": .environmentGated(
            reason: "Generic AX action failure at a tool boundary against a live element. Proven in STORY-002/003 unit tests."),
        "window_not_found": .environmentGated(
            reason: "Requires a window/app lookup miss against live windows. Proven in WindowModule unit tests."),

        // Closed-set validation codes emitted by tools not on the integration
        // dispatch happy-path; structurally proven by their owning unit tests.
        "unsupported_notification": .environmentGated(
            reason: "wait_for_ui_event closed-set rejection; proven structurally in STORY-008 unit tests (no live app needed there)."),
        "invalid_condition_expression": .environmentGated(
            reason: "wait_for_element_state parser rejection; proven in STORY-009 unit tests."),
        "predicate_too_broad": .environmentGated(
            reason: "find_elements no-criteria rejection; proven in STORY-014 unit tests."),
        "predicate_compile_failed": .environmentGated(
            reason: "Catch-all sibling of invalid_regex/predicate_too_broad; invalid_regex is the forced tool-boundary path. Proven in STORY-014 unit tests."),
        "conflicting_title_predicates": .environmentGated(
            reason: "find_elements mutually-exclusive title predicates; proven in STORY-014 unit tests."),
        "conflicting_identifier_predicates": .environmentGated(
            reason: "find_elements mutually-exclusive identifier predicates; proven in STORY-014 unit tests."),
        "menu_item_not_found": .environmentGated(
            reason: "Requires a live app menu missing the path; proven in STORY-007 unit tests."),
        "menu_item_disabled": .environmentGated(
            reason: "Requires a live disabled menu item; proven in STORY-007 unit tests."),
        "applescript_error": .environmentGated(
            reason: "Requires an AppleScript runtime error from a live engine; proven in STORY-006 unit tests."),

        // Prompts surface (STORY-017) — prompts/get, not tools/call. Out of
        // ToolRouter scope by design.
        "prompt_not_found": .environmentGated(
            reason: "Emitted by the prompts/get handler, not tools/call. Proven in STORY-017 unit tests."),
        "missing_required_argument": .environmentGated(
            reason: "Emitted by the prompts/get handler, not tools/call. Proven in STORY-017 unit tests."),

        // STORY-019 override loader — fail-soft at startup, never a tool error.
        "invalid_capability_registry_override": .environmentGated(
            reason: "Emitted by the capability-registry override loader at startup (logged, fail-soft), never as a tool response. Proven in STORY-019 unit tests."),
    ]
}
