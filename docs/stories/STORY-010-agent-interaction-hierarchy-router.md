# STORY-010 — Agent Interaction Hierarchy Router

**Epic:** EPIC-6 · Agent Interaction Hierarchy
**Priority:** 🟡 High
**Story Points:** 5
**Sprint Target:** Sprint 4
**Dependencies:** 🔒 STORY-002 (Semantic Click), 🔒 STORY-003 (AX Action Performer), 🔒 STORY-005 (Element At Position Hit-Test), 🔒 STORY-006 (run_applescript), 🔒 STORY-008 (wait_for_ui_event), 🔒 STORY-016 (Structured Errors), 🔒 STORY-017 (MCP Prompts — `interaction_hierarchy` prompt), 🔒 STORY-019 (Per-App Capability Registry)
**Refinement Round:** 7 — Epic 6 expansion. Scenarios 4 → 9; added hit-test (4th layer) coverage, type intent, all-layers-failed error path, decision audit log; dependencies updated to reflect Round 5 additions (STORY-017) and Round 7 additions (STORY-005, STORY-019).

---

## 1. User Story Narrative

```
Story: Agent Interaction Hierarchy Router
In order to always use the most reliable available interaction method without manual layer selection
As an AI agent using the MCP server
I want a smart_interact MCP tool that automatically selects and falls through interaction layers in canonical order
So that interactions succeed gracefully across AX-supported apps, AppleScript-scriptable apps, and unsupported legacy apps
```

**Additional Context:** This is the keystone story of Epic 6 — the user-visible synthesis of every prior epic. Epic 6's stated goal calls out **four** layers in canonical order: (1) **AX semantic** (STORY-002 / STORY-003), (2) **AppleScript** (STORY-006), (3) **visual hit-test** (STORY-005 — convert a coordinate to an AX element via `element_at_position`, then `AXPress`), (4) **raw coordinate** (existing `click_screen` / `type_text`). The router is the difference between an agent that has to know which tool to use and an agent that gets the right behavior by stating intent. The router consumes STORY-019's per-app capability registry to skip layers known to fail for a given target app (e.g., Electron apps with broken AX trees), reducing both wall-clock time and noisy failure logs.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-6 @story-010 @mcp-tool @router
Feature: Agent Interaction Hierarchy Router
  In order to use the most reliable interaction method automatically
  As an AI agent
  I want smart_interact to route through AX → AppleScript → hit-test → coordinate layers in order

  Background:
    Given the MCP server is running with all Epic 1, 2, 3, 5 tools available
    And the per-app capability registry from STORY-019 is loaded

  # --- Round 4 scenarios (preserved, refined to STORY-016 error shape) ---

  Scenario: Route to AX semantic layer when element is accessible
    Given "TextEdit" is open with a "Bold" button that has a valid AXIdentifier
    When the AI agent calls smart_interact with intent "click" and target "Bold button in TextEdit toolbar"
    Then the interaction is performed via the AX semantic layer
    And the response includes "interaction_method": "ax_semantic"
    And the response includes "confidence" between 0.9 and 1.0
    And the response includes a decision_log entry showing ax_semantic succeeded on the first attempt

  Scenario: Fall back to AppleScript when AX layer fails
    Given an application whose target action has no AXAction binding
    But the application has a documented AppleScript dictionary entry for the action
    When the AI agent calls smart_interact with intent "open document" and target application "Script Editor"
    Then the AX layer is attempted and skipped with a documented reason
    And the interaction is performed via run_applescript
    And the response includes "interaction_method": "applescript"
    And the response's decision_log shows ax_semantic was tried, then skipped, then applescript succeeded

  Scenario: Fall back to coordinate click as last resort
    Given an application with no AX support and no AppleScript dictionary
    And a screenshot shows a clickable area at coordinates (500, 400)
    When the AI agent calls smart_interact with intent "click" and coordinates (500, 400)
    Then all higher layers are attempted and skipped or fail
    And the interaction is performed via the existing coordinate-based mouse click tool
    And the response includes "interaction_method": "coordinate_fallback"
    And the response includes a warning that coordinate-based clicks are less reliable
    And the response's decision_log lists every attempted layer with skip/fail reason

  Scenario: Record interaction layer and confidence in every response
    Given any application and any successful interaction
    When the AI agent calls smart_interact
    Then the response always includes "interaction_method"
    And the response always includes "confidence" between 0 and 1
    And the response always includes a non-empty decision_log array

  # --- Round 7 additions: hit-test layer, type intent, all-failures, registry, audit ---

  Scenario: Fall back to visual hit-test layer when AX-by-name fails but visual coordinates are provided
    Given an application with partial AX support — elements exist in the tree but lack stable identifiers or titles
    And the agent supplies visual coordinates (320, 180) from a screenshot
    When the AI agent calls smart_interact with intent "click", target description "Submit button", and coordinates (320, 180)
    Then the AX-by-name layer is attempted and fails to resolve
    Then the hit-test layer uses element_at_position to recover an AXUIElement at (320, 180)
    And the recovered element receives AXPress via perform_ax_action
    And the response includes "interaction_method": "ax_hit_test"
    And the response's decision_log records the (x, y) coordinates used by the hit-test layer

  Scenario: Type intent uses its own three-layer hierarchy
    Given "TextEdit" is open with a focused text area
    When the AI agent calls smart_interact with intent "type" and value "hello world"
    Then the AX layer attempts AXSetAttribute(AXValue, "hello world") first
    And on AX failure the AppleScript layer attempts to set the text-field value
    And on AppleScript failure the coordinate layer falls back to focusing the field and dispatching type_text
    And the response includes the layer that succeeded
    And the response's decision_log captures the layer ordering for the type intent

  Scenario: All layers fail — return structured all_layers_failed error
    Given an application that is in a frozen or unresponsive state
    When the AI agent calls smart_interact with intent "click" and target "any button"
    And every available layer fails
    Then the tool returns a structured error with error_code "all_layers_failed"
    And the error details include the full decision_log of attempts and failure reasons
    And the error suggests retry strategies (different intent, wait_for_app_event for unfreeze, manual fallback)

  Scenario: Capability registry skips layers known to fail for the target app
    Given the per-app capability registry marks bundle_id "com.electron.exampleapp" with ax_supported = false
    When the AI agent calls smart_interact with intent "click" target "Save in com.electron.exampleapp"
    Then the AX semantic layer is skipped without an attempt
    And the response's decision_log shows ax_semantic was skipped with reason "registry: ax_supported=false"
    And the interaction proceeds directly to the AppleScript layer

  Scenario: Decision audit log is always present, ordered, and structured
    Given any smart_interact call regardless of outcome
    When the response is returned
    Then the response includes a "decision_log" array
    And each decision_log entry has "layer", "attempted", "outcome" (one of: "succeeded", "skipped", "failed"), "reason"
    And entries are ordered by attempt time
    And the array has at least one entry even when the first layer succeeds
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | AX semantic layer succeeds | ✅ |
| Alternative success path | AppleScript fallback; hit-test fallback; coordinate fallback; type intent | ✅ |
| Boundary condition | Decision log always present (even on first-layer success); confidence range | ✅ |
| Error / rejection path | All layers fail with structured `all_layers_failed` error | ✅ |
| Business rule edge case | Registry-driven layer skipping; visible audit of skip reasons | ✅ |

---

## 4. Three Amigos Open Questions (Round 7)

| # | Question | Resolution |
|---|---|---|
| Q1 | Optimistic ("try each layer, catch errors") vs registry-driven layer selection? | **Both — registry first, optimistic for layers the registry doesn't classify.** Registry hits are fast and avoid noisy attempts on known-broken apps. Unknown apps fall through optimistically. Splitting the registry into STORY-019 makes this decision data-driven and testable. |
| Q2 | `confidence` field — what does it actually mean? | **Method-specific baseline reduced by attempt count.** AX semantic = 0.95 baseline. AppleScript = 0.85. Hit-test = 0.75. Coordinate = 0.50. Multiply by 0.9 for each prior failed layer. _[NEEDS CONFIRMATION: real-world calibration via STORY-020 catalog data]_ |
| Q3 | When the AX layer fails, what failure modes count as "skip" vs "fail" in the decision_log? | **Skip:** registry said so, or AX permission missing system-wide. **Fail:** an attempt was actually made and got a structured error from the underlying tool. The distinction matters for the agent's debugging: skips are configuration; fails are runtime. |
| Q4 | Routing for non-click, non-type intents (drag, scroll, select)? | **Out of scope for v1.** v1 supports `click` and `type`. Drag/scroll/select can be added in a future story without router redesign — the layer-fallback skeleton is intent-agnostic. _[NEEDS CONFIRMATION]_ |
| Q5 | Should `smart_interact` accept the existing per-tool input shapes verbatim (`element_locator`, etc.) or define its own intent-first input? | **Intent-first.** `{ intent, target_description, application?, coordinates?, value?, ... }`. The router translates intent + target into per-layer tool inputs internally. This keeps the agent's prompt vocabulary stable while layer implementations evolve. |
| Q6 | Per-call layer-skip override (`skip_layers: ["coordinate_fallback"]`)? | **Yes, accepted via input parameter.** Useful for tests and for agents who know coordinate fallback is dangerous in their context. Default: no skips. |
| Q7 | What happens if a higher layer succeeds but produces a wrong result (e.g., AXPress was on the wrong element)? | **Not the router's job.** Verification post-action is the agent's responsibility via `wait_for_ui_event` / `wait_for_element_state` (STORY-008 / STORY-009). The router only knows if the action dispatched successfully, not if it had the intended effect. Documented in the `interaction_hierarchy` MCP Prompt under "verify after acting". |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| AX layer success | When tool called | When | `InteractionRouter.route(input:)` | test_dispatches_to_ax_when_registry_permits, test_returns_first_layer_success |
| AX → AppleScript fallback | Given no AXAction | Given | `AXSemanticLayer.attempt(intent:)` | test_returns_skipped_when_no_AXAction_binding |
| AX → AppleScript fallback | When fallback occurs | When | `InteractionRouter.route(input:)` | test_falls_through_to_next_layer_on_skipped_or_failed |
| Coordinate fallback | When all higher layers exhausted | When | `CoordinateLayer.attempt(intent:)` | test_dispatches_to_existing_mouse_tool, test_includes_reliability_warning_in_response |
| Hit-test layer | When AX-by-name fails with coordinates | When | `HitTestLayer.attempt(intent:)` | test_calls_element_at_position_then_perform_ax_action, test_records_coordinates_in_decision_log |
| Type intent | When intent=type | When | `InteractionRouter.route(input:)` | test_dispatches_type_intent_through_type_specific_hierarchy, test_type_falls_back_to_keyboard_simulation |
| All layers fail | When every layer returns error | When | `InteractionRouter.route(input:)` | test_returns_AllLayersFailedError_with_decision_log, test_error_details_include_retry_suggestions |
| Registry skip | Given registry marks ax_supported=false | Given | `InteractionRouter.shouldSkip(layer:forApp:)` | test_consults_registry_for_layer_eligibility |
| Registry skip | Then ax_semantic skipped | Then | `DecisionLog.append(...)` | test_decision_log_records_skip_with_registry_reason |
| Decision audit always present | Then array present | Then | `InteractionRouter` response builder | test_decision_log_always_has_at_least_one_entry, test_decision_log_entries_have_layer_attempted_outcome_reason |

---

## 6. TDD Unit Test Scaffolds

### 6.1 `InteractionRouter` (new Epic 6 foundation)

```swift
// FILE: Tests/MCP-MacOSControlTests/Router/InteractionRouterTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: InteractionRouter

import XCTest
@testable import MacOSControlLib

final class InteractionRouterTests: XCTestCase {

    var router: InteractionRouter!
    var fakeAXLayer: FakeInteractionLayer!
    var fakeAppleScriptLayer: FakeInteractionLayer!
    var fakeHitTestLayer: FakeInteractionLayer!
    var fakeCoordinateLayer: FakeInteractionLayer!
    var fakeRegistry: FakeAppCapabilityRegistry!

    override func setUp() {
        super.setUp()
        fakeAXLayer = FakeInteractionLayer(name: "ax_semantic")
        fakeAppleScriptLayer = FakeInteractionLayer(name: "applescript")
        fakeHitTestLayer = FakeInteractionLayer(name: "ax_hit_test")
        fakeCoordinateLayer = FakeInteractionLayer(name: "coordinate_fallback")
        fakeRegistry = FakeAppCapabilityRegistry()
        router = InteractionRouter(
            layers: [fakeAXLayer, fakeAppleScriptLayer, fakeHitTestLayer, fakeCoordinateLayer],
            registry: fakeRegistry)
    }

    // MARK: - Happy Path

    func test_route_returnsFirstLayerSuccess() async throws {
        fakeAXLayer.stubbedOutcome = .succeeded(method: "ax_semantic", confidence: 0.95)
        let input = SmartInteractInput(intent: .click, targetDescription: "Bold", application: "TextEdit")
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "ax_semantic")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
        XCTAssertEqual(result.decisionLog.count, 1)
        XCTAssertEqual(result.decisionLog[0].outcome, .succeeded)
    }

    func test_route_fallsThroughToNextLayer_onSkipped() async throws {
        fakeAXLayer.stubbedOutcome = .skipped(reason: "no AXAction binding")
        fakeAppleScriptLayer.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)
        let input = SmartInteractInput(intent: .click, targetDescription: "Open", application: "Script Editor")
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "applescript")
        XCTAssertEqual(result.decisionLog.count, 2)
        XCTAssertEqual(result.decisionLog[0].outcome, .skipped)
        XCTAssertEqual(result.decisionLog[1].outcome, .succeeded)
    }

    func test_route_fallsThroughToNextLayer_onFailed() async throws {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "ax_action_failed", message: "AXPress returned -25204")
        fakeAppleScriptLayer.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)
        let input = SmartInteractInput(intent: .click, targetDescription: "Open", application: "LegacyApp")
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "applescript")
        XCTAssertEqual(result.decisionLog[0].outcome, .failed)
        XCTAssertEqual(result.decisionLog[0].reason, "ax_action_failed: AXPress returned -25204")
    }

    // MARK: - Hit-test layer

    func test_route_usesHitTestLayer_whenAXByNameFailsAndCoordinatesProvided() async throws {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "element_not_found", message: "no match for 'Submit'")
        fakeAppleScriptLayer.stubbedOutcome = .skipped(reason: "no AppleScript dictionary")
        fakeHitTestLayer.stubbedOutcome = .succeeded(method: "ax_hit_test", confidence: 0.75)
        let input = SmartInteractInput(intent: .click, targetDescription: "Submit",
                                       application: "PartialApp", coordinates: CGPoint(x: 320, y: 180))
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "ax_hit_test")
        let hitTestEntry = result.decisionLog.first { $0.layer == "ax_hit_test" }
        XCTAssertEqual(hitTestEntry?.metadata["coordinates"] as? String, "(320.0, 180.0)")
    }

    // MARK: - Type intent

    func test_route_typeIntent_usesTypeSpecificHierarchy() async throws {
        fakeAXLayer.stubbedOutcome = .succeeded(method: "ax_semantic", confidence: 0.95)
        let input = SmartInteractInput(intent: .type, application: "TextEdit", value: "hello world")
        let result = await router.route(input: input)
        // AX layer must have been called with a type-specific request
        XCTAssertEqual(fakeAXLayer.lastIntent, .type)
        XCTAssertEqual(fakeAXLayer.lastValue, "hello world")
        XCTAssertEqual(result.interactionMethod, "ax_semantic")
    }

    func test_route_typeIntent_fallsBackToKeyboardSimulation() async throws {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "ax_setvalue_unsupported", message: "")
        fakeAppleScriptLayer.stubbedOutcome = .failed(errorCode: "applescript_no_dictionary", message: "")
        fakeHitTestLayer.stubbedOutcome = .skipped(reason: "type intent does not use hit-test")
        fakeCoordinateLayer.stubbedOutcome = .succeeded(method: "coordinate_fallback", confidence: 0.5)
        let input = SmartInteractInput(intent: .type, application: "LegacyApp", value: "hi")
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "coordinate_fallback")
    }

    // MARK: - All Layers Failed

    func test_route_returnsAllLayersFailedError_whenEveryLayerFails() async {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "frozen_app", message: "timeout")
        fakeAppleScriptLayer.stubbedOutcome = .failed(errorCode: "frozen_app", message: "timeout")
        fakeHitTestLayer.stubbedOutcome = .failed(errorCode: "no_hit_at_position", message: "")
        fakeCoordinateLayer.stubbedOutcome = .failed(errorCode: "rate_limited", message: "")
        let input = SmartInteractInput(intent: .click, targetDescription: "Anything", application: "FrozenApp")
        let result = await router.route(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "all_layers_failed")
        XCTAssertEqual((result.details["decision_log"] as? [Any])?.count, 4)
        XCTAssertNotNil(result.details["retry_suggestions"])
    }

    // MARK: - Registry-driven skipping

    func test_route_skipsLayer_whenRegistryDisallows() async throws {
        fakeRegistry.stubCapability(forBundle: "com.electron.exampleapp",
                                    axSupported: false, applescriptSupported: true)
        fakeAppleScriptLayer.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)
        let input = SmartInteractInput(intent: .click, targetDescription: "Save",
                                       application: "com.electron.exampleapp")
        let result = await router.route(input: input)
        XCTAssertEqual(fakeAXLayer.callCount, 0, "AX layer should be skipped, not called")
        XCTAssertEqual(result.decisionLog[0].layer, "ax_semantic")
        XCTAssertEqual(result.decisionLog[0].outcome, .skipped)
        XCTAssertTrue(result.decisionLog[0].reason.contains("registry"))
    }

    func test_route_acceptsPerCallSkipLayersOverride() async throws {
        fakeAppleScriptLayer.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)
        let input = SmartInteractInput(intent: .click, targetDescription: "Save",
                                       application: "TextEdit",
                                       skipLayers: ["ax_semantic"])
        let result = await router.route(input: input)
        XCTAssertEqual(fakeAXLayer.callCount, 0)
        XCTAssertEqual(result.interactionMethod, "applescript")
    }

    // MARK: - Decision log invariants

    func test_decisionLog_isAlwaysNonEmpty_evenOnFirstLayerSuccess() async throws {
        fakeAXLayer.stubbedOutcome = .succeeded(method: "ax_semantic", confidence: 0.95)
        let input = SmartInteractInput(intent: .click, targetDescription: "Bold", application: "TextEdit")
        let result = await router.route(input: input)
        XCTAssertGreaterThanOrEqual(result.decisionLog.count, 1)
    }

    func test_decisionLog_entriesAreOrderedByAttemptTime() async throws {
        fakeAXLayer.stubbedOutcome = .skipped(reason: "no AX")
        fakeAppleScriptLayer.stubbedOutcome = .skipped(reason: "no AS dictionary")
        fakeHitTestLayer.stubbedOutcome = .succeeded(method: "ax_hit_test", confidence: 0.75)
        let input = SmartInteractInput(intent: .click, targetDescription: "X", application: "App",
                                       coordinates: CGPoint(x: 1, y: 1))
        let result = await router.route(input: input)
        XCTAssertEqual(result.decisionLog.map(\.layer),
                       ["ax_semantic", "applescript", "ax_hit_test"])
    }
}
```

### 6.2 `InteractionLayer` protocol conformances (one per layer)

```swift
// FILE: Tests/MCP-MacOSControlTests/Router/AXSemanticLayerTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: AXSemanticLayer (adapter over STORY-002/003)

import XCTest
@testable import MacOSControlLib

final class AXSemanticLayerTests: XCTestCase {

    var layer: AXSemanticLayer!
    var fakeClickTool: FakeClickElementTool!
    var fakeActionTool: FakePerformAXActionTool!

    override func setUp() {
        super.setUp()
        fakeClickTool = FakeClickElementTool()
        fakeActionTool = FakePerformAXActionTool()
        layer = AXSemanticLayer(clickTool: fakeClickTool, actionTool: fakeActionTool)
    }

    func test_attempt_click_dispatchesToClickElementTool() async throws {
        fakeClickTool.stubbedResult = .success(element: makeFakeElement())
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Bold", app: "TextEdit"))
        if case .succeeded(let method, _) = outcome {
            XCTAssertEqual(method, "ax_semantic")
        } else {
            XCTFail("Expected succeeded outcome, got \(outcome)")
        }
        XCTAssertEqual(fakeClickTool.callCount, 1)
    }

    func test_attempt_type_dispatchesToAXSetValueBeforeClick() async throws {
        // type intent should set AXValue directly, not click
        fakeActionTool.stubbedResult = .success
        let outcome = await layer.attempt(.type, target: TargetSpec(app: "TextEdit", value: "hi"))
        if case .succeeded = outcome { /* OK */ }
        else { XCTFail("Expected succeeded") }
        XCTAssertEqual(fakeActionTool.lastAction, "AXSetAttribute:AXValue")
        XCTAssertEqual(fakeClickTool.callCount, 0)
    }

    func test_attempt_returnsSkipped_whenAXPermissionDenied() async {
        fakeClickTool.stubbedResult = .failure(.permissionDenied)
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "X", app: "Y"))
        if case .skipped(let reason) = outcome {
            XCTAssertTrue(reason.contains("permission"))
        } else {
            XCTFail("Expected skipped, got \(outcome)")
        }
    }

    func test_attempt_returnsFailed_whenElementNotFound() async {
        fakeClickTool.stubbedResult = .failure(.elementNotFound)
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Ghost", app: "Y"))
        if case .failed(let code, _) = outcome {
            XCTAssertEqual(code, "element_not_found")
        } else {
            XCTFail("Expected failed")
        }
    }
}
```

> Analogous test classes are required for `AppleScriptLayerTests`, `HitTestLayerTests`, and `CoordinateLayerTests`. Each adapter test exercises happy-path dispatch + skip-path (capability missing) + fail-path (underlying tool returned structured error).

### 6.3 `SmartInteractTool` (MCP tool surface)

```swift
// FILE: Tests/MCP-MacOSControlTests/Modules/SmartInteractToolTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: SmartInteractTool

import XCTest
@testable import MacOSControlLib

final class SmartInteractToolTests: XCTestCase {

    var tool: SmartInteractTool!
    var fakeRouter: FakeInteractionRouter!

    override func setUp() {
        super.setUp()
        fakeRouter = FakeInteractionRouter()
        tool = SmartInteractTool(router: fakeRouter)
    }

    func test_execute_validatesRequiredIntent() async {
        let result = await tool.execute(input: ["application": "TextEdit"])
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "missing_required_field")
    }

    func test_execute_validatesIntentEnum() async {
        let result = await tool.execute(input: ["intent": "telepathy", "application": "TextEdit"])
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "unsupported_intent")
    }

    func test_execute_passesInputToRouterUnchanged() async {
        fakeRouter.stubbedResult = RouterResult(method: "ax_semantic", confidence: 0.95, decisionLog: [])
        let result = await tool.execute(input: [
            "intent": "click",
            "target_description": "Bold",
            "application": "TextEdit"
        ])
        XCTAssertFalse(result.isError)
        XCTAssertEqual(fakeRouter.lastInput?.intent, .click)
        XCTAssertEqual(fakeRouter.lastInput?.application, "TextEdit")
    }

    func test_execute_includesDecisionLogInResponse() async {
        fakeRouter.stubbedResult = RouterResult(
            method: "applescript", confidence: 0.85,
            decisionLog: [
                DecisionLogEntry(layer: "ax_semantic", outcome: .skipped, reason: "no AXAction"),
                DecisionLogEntry(layer: "applescript", outcome: .succeeded, reason: "")
            ])
        let result = await tool.execute(input: ["intent": "click", "application": "X"])
        let log = result.content["decision_log"] as? [[String: Any]]
        XCTAssertEqual(log?.count, 2)
        XCTAssertEqual(log?[0]["layer"] as? String, "ax_semantic")
        XCTAssertEqual(log?[1]["outcome"] as? String, "succeeded")
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Source | Notes |
|---|---|---|---|
| `ClickElementTool` (STORY-002) | Real | `FakeClickElementTool` | Wrapped by `AXSemanticLayer` |
| `PerformAXActionTool` (STORY-003) | Real | `FakePerformAXActionTool` | Wrapped by `AXSemanticLayer` for type intent (`AXSetAttribute`) |
| `ElementAtPositionTool` (STORY-005) | Real | `FakeElementAtPositionTool` | Wrapped by `HitTestLayer` |
| `RunAppleScriptTool` (STORY-006) | Real | `FakeRunAppleScriptTool` | Wrapped by `AppleScriptLayer` |
| `MouseControl` / `KeyboardControl` (existing) | Real | Existing fakes | Wrapped by `CoordinateLayer` |
| `AppCapabilityRegistry` (STORY-019) | **New** | `FakeAppCapabilityRegistry` | Consulted before each layer attempt |
| `ErrorCodeRegistry` (STORY-016) | Real | No double | Registers `all_layers_failed`, `unsupported_intent`, `missing_required_field` |
| `InteractionLayer` protocol | **New** | `FakeInteractionLayer` | Allows the router to be tested without real Swift accessibility C-calls |

---

## 8. Definition of Done

**Tool contract**
- [ ] `smart_interact` registered in `ToolRouter` via a new `SmartInteractModule`
- [ ] Input schema: `intent` (enum: `click`, `type`), `target_description` (string, optional), `application` (string, optional — bundle id or name), `coordinates` (object `{x, y}`, optional), `value` (string, required when `intent=type`), `skip_layers` (array of strings, optional)
- [ ] Output schema on success: `{ interaction_method, confidence, decision_log, result: <layer-specific payload> }`
- [ ] Output schema on error: STORY-016 structured error contract; primary code `all_layers_failed`
- [ ] `Tool.Annotations`: `readOnlyHint: false`, `idempotentHint: false`, `destructiveHint: true` (conservative — could click any control)

**Four-layer routing (matches Epic 6 goal)**
- [ ] `AXSemanticLayer` adapter over STORY-002 / STORY-003
- [ ] `AppleScriptLayer` adapter over STORY-006
- [ ] `HitTestLayer` adapter over STORY-005 + STORY-003 (coordinate → element_at_position → AXPress)
- [ ] `CoordinateLayer` adapter over existing `MouseControl` / `KeyboardControl`
- [ ] Each layer conforms to a shared `InteractionLayer` protocol with `attempt(_:target:) async -> LayerOutcome`

**Registry consultation (STORY-019 integration)**
- [ ] Router consults `AppCapabilityRegistry` before invoking each layer
- [ ] Registry skip reasons appear in `decision_log` with prefix `registry: …`
- [ ] Unknown apps fall through to optimistic attempts

**Decision audit log**
- [ ] Every response (success or error) includes a `decision_log` array
- [ ] Each entry: `{ layer, attempted: bool, outcome: "succeeded"|"skipped"|"failed", reason, elapsed_ms, metadata }`
- [ ] Log is ordered by attempt time
- [ ] Even first-layer success produces a one-entry log

**Error contract registered with STORY-016**
- [ ] `all_layers_failed` — details include `decision_log` and `retry_suggestions`
- [ ] `unsupported_intent` — details list supported intents
- [ ] `missing_required_field` — details name the missing field

**MCP Prompt integration (STORY-017)**
- [ ] The `interaction_hierarchy` MCP Prompt is updated to reference `smart_interact` as the preferred entry point
- [ ] The prompt documents when to bypass `smart_interact` (e.g., explicit coordinate-only contexts, type-without-target)
- [ ] The prompt explicitly states "verify after acting" (post-action `wait_for_*` calls) — addressing Three Amigos Q7

**Tests**
- [ ] All BDD scenarios pass in CI (Cucumberish `story-010-agent-interaction-hierarchy-router.feature`)
- [ ] Unit coverage ≥ 85% on `InteractionRouter`
- [ ] Unit coverage ≥ 80% on each layer adapter
- [ ] Living documentation generator maps every scenario to ≥ 1 unit test

**Documentation**
- [ ] `docs/stories/STORY-010-agent-interaction-hierarchy-router.md` (this file) committed
- [ ] `Tests/MCP-MacOSControlTests/Features/story-010-agent-interaction-hierarchy-router.feature` committed
- [ ] README updated: `smart_interact` listed as the recommended interaction tool for AI agents

---

## 9. Notes & Observations

- **Why not split STORY-010 by intent (click-only / type-only)?** The Cardinal Rule analog at the tool level says one user-visible feature → one story. `smart_interact` is the user-visible feature. Internal intent dispatch is implementation detail. Splitting by intent fragments scenarios without reducing complexity. If sprint velocity requires it, splitting by *layer* (Round 4's 3 layers as 010a, hit-test + type as 010b) is the cheaper cut — same skeleton, additive scenarios.
- **Why does the AX layer handle both click AND type?** The layer is defined by *how* it interacts (semantic AX), not by *what* it does. AXPress and `AXSetAttribute(AXValue, …)` are both AX semantic actions; they share input resolution, error handling, and observability semantics. Splitting them into separate layers triples the layer count without clarifying anything.
- **Why is `destructiveHint: true`?** A `smart_interact` call could click a Delete button or overwrite text. Conservative annotation matches the Round 5 STORY-011 decision for `click_element` / `perform_ax_action`.
- **Routing for non-click, non-type intents.** v1 supports two intents. The `InteractionLayer` protocol is intent-generic; adding drag/scroll/select later is additive (new intent enum cases, new layer methods, no router redesign). Track as a Round 8+ candidate.
- **Relationship to STORY-019 (registry):** STORY-019 ships first. STORY-010 consumes it. If STORY-019 slips, STORY-010 can ship with an always-permissive registry (`return AllSupported`) and the optimistic-fallback path still works — just slower on known-broken apps. The decoupling is genuine.
- **Relationship to STORY-012 (integration suite):** STORY-012 is the proving ground for the router. Several STORY-012 scenarios assume `smart_interact` exists. Sprint placement: STORY-010 must precede STORY-012; STORY-019 must precede STORY-010.
