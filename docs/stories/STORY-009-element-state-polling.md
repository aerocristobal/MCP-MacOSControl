# STORY-009 — Element State Polling Tool

**Epic:** EPIC-5 · Event-Driven Waiting & Observers
**Priority:** 🟡 High
**Story Points:** 3  _(was 2 — bumped Round 6 to cover STORY-015 state fields)_
**Sprint Target:** Sprint 3
**Dependencies:** 🔒 STORY-004 (Enhanced AX Tree), 🔒 STORY-015 (Extended Element State Attributes), 🔒 STORY-016 (Structured Error Response Contract)
**Refinement Round:** 6 — Epic 5 expansion. Scenarios 3 → 7; condition vocabulary expanded to match STORY-015 fields; added value-equality and disappear scenarios; dependency on STORY-015 made explicit.

---

## 1. User Story Narrative

```
Story: Element State Polling Tool
In order to wait for an element to reach a specific state when no AXObserver notification exists for that transition
As an AI agent using the MCP server
I want a wait_for_element_state tool that polls the AX tree until an element matches a state predicate
So that I can handle animations, async UI updates, and conditions outside the AXObserver vocabulary without brittle fixed sleeps
```

**Additional Context:** Complementary to STORY-008. AXObserver covers a fixed vocabulary of AX notifications (window created, focus changed, value changed, etc.). Many practical agent needs fall outside that vocabulary: "wait until the Submit button becomes enabled," "wait until the spinner is no longer visible in the viewport," "wait until this row is selected." Those transitions don't have dedicated AX notifications, so polling is necessary. The polling tool reuses STORY-004's tree builder and STORY-015's extended state fields — every flag the serializer emits is a flag this tool can wait for. STORY-008 is the preferred path when a notification exists; this tool is the documented fallback.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-5 @story-009 @mcp-tool
Feature: Element State Polling Tool
  In order to wait for UI conditions that AXObserver does not expose
  As an AI agent
  I want wait_for_element_state to poll until an element matches a state predicate

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  # --- Round 4 scenarios (preserved, refined to STORY-016 error shape) ---

  Scenario: Wait resolves when a button becomes enabled
    Given a form with a "Submit" button that is initially disabled
    When the AI agent calls wait_for_element_state with role "AXButton", title "Submit", and condition "enabled = true"
    And the form is completed making the Submit button enabled
    Then the tool returns a success response
    And the response includes the element shape with "enabled": true and "schema_version": 3

  Scenario: Wait resolves when an element appears in the tree
    Given a loading spinner is displayed with no content elements yet
    When the AI agent calls wait_for_element_state with role "AXList" and condition "exists = true"
    And the content list appears after loading
    Then the tool returns a success response with the list element's properties

  Scenario: Return timeout error if condition is not met
    Given a button that remains disabled throughout the test
    When the AI agent calls wait_for_element_state for that button with condition "enabled = true" and timeout 3 seconds
    Then the tool returns a structured error with error_code "state_condition_not_met"
    And the error details include the current state of the element
    And the error details include the elapsed time

  # --- Round 6 additions: STORY-015 state fields and value-equality ---

  Scenario: Wait resolves when an element becomes focused
    Given a form with multiple text fields visible
    And no field is currently focused
    When the AI agent calls wait_for_element_state with role "AXTextField", title "Username", and condition "focused = true"
    And focus is moved into the Username field
    Then the tool returns a success response
    And the response includes the element shape with "focused": true

  Scenario: Wait resolves when an element disappears from the tree
    Given a "Saving…" progress indicator is visible
    When the AI agent calls wait_for_element_state with role "AXProgressIndicator" and condition "exists = false"
    And the indicator is removed when the save completes
    Then the tool returns a success response
    And the response indicates the element no longer exists

  Scenario: Wait resolves when an element's value matches a target string
    Given a status label currently displays "Connecting…"
    When the AI agent calls wait_for_element_state with role "AXStaticText" identifier "status-label" and condition "value = 'Connected'"
    And the label text changes to "Connected"
    Then the tool returns a success response
    And the response includes the element with "value": "Connected"

  Scenario: Reject malformed condition expression
    Given any application is open
    When the AI agent calls wait_for_element_state with condition "selected = banana = true"
    Then the tool returns a structured error with error_code "invalid_condition_expression"
    And the error details name the supported condition operators and fields

  Scenario Outline: Support every state field that the serializer emits
    Given an element exists matching <locator> with <field> currently <initial_value>
    When the AI agent calls wait_for_element_state for that element with condition "<field> = <target_value>"
    And the element's <field> changes to <target_value>
    Then the tool returns a success response within the timeout
    And the response includes <field> = <target_value>

    Examples:
      | locator                  | field                  | initial_value | target_value |
      | role=AXButton            | enabled                | false         | true         |
      | role=AXButton            | exists                 | false         | true         |
      | role=AXTextField         | focused                | false         | true         |
      | role=AXMenuItem          | selected               | false         | true         |
      | role=AXDisclosureTriangle| expanded               | false         | true         |
      | role=AXButton            | visible_in_viewport    | false         | true         |
      | role=AXWindow            | is_main                | false         | true         |
      | role=AXWindow            | is_minimized           | false         | true         |
      | role=AXWindow            | is_frontmost           | false         | true         |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | Button becomes enabled | ✅ |
| Alternative success path | Element appears; element disappears; value matches; focus arrives | ✅ |
| Boundary condition | Outline covers every STORY-015 state field | ✅ |
| Error / rejection path | Timeout when condition not met; malformed expression | ✅ |
| Business rule edge case | `exists = false` (disappearance) handled symmetrically with `exists = true` | ✅ |

---

## 4. Three Amigos Open Questions (Round 6)

| # | Question | Resolution |
|---|---|---|
| Q1 | Polling interval — fixed or adaptive? | **Fixed at 100ms default**, server-config override only. Adaptive backoff adds complexity without obvious user benefit for sub-second UI transitions. _[NEEDS CONFIRMATION]_ |
| Q2 | If the element resolver itself fails on the very first poll (no element at all, condition is not `exists = false`), do we return `element_not_found` immediately or wait the full timeout? | **Wait the full timeout.** "Not found yet" is the same shape as "not in expected state yet" — both are caller-driven retries handled by the timeout. The `exists` predicate is the deliberate way to test for presence. |
| Q3 | What's the maximum allowed timeout? | **120 seconds.** Lower than STORY-008's 300s cap because polling has steady cost; long polls should reach for STORY-008 (event-driven) or STORY-013 (resource-subscription) instead. _[NEEDS CONFIRMATION]_ |
| Q4 | Value-equality semantics — exact match, case-sensitive? Numeric vs string? | **Exact match, case-sensitive, string comparison only at v1.** Numeric and substring predicates deferred to a future story unless a Three Amigos session disagrees. _[NEEDS CONFIRMATION]_ |
| Q5 | If the user passes both `state` (legacy from Round 4) and the new structured `condition`, which wins? | **`condition` wins; `state` deprecated.** Backwards compatibility: accept `state = "enabled = true"` as an alias for `condition = "enabled = true"` for one minor version, then remove. |
| Q6 | Cancellation while polling | **Deferred** — same as STORY-008 Q5. MCP protocol-level cancellation, not story-local. |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| Button enabled | When tool called | When | `WaitForElementStateTool.execute(input:)` | test_returns_success_when_predicate_becomes_true |
| Button enabled | Then response includes schema_version=3 | Then | `AXNodeSerializer` (reused) | reuse from STORY-015 |
| Element appears | When tool called with exists=true | When | `WaitForElementStateTool` | test_returns_success_when_resolver_starts_returning_match |
| Timeout | When predicate never satisfied | When | `ElementStatePollLoop.poll(...)` | test_returns_StateConditionNotMetError_with_current_state |
| Element becomes focused | When focus moves | When | `ConditionPredicate.evaluate(node:)` | test_focused_predicate_returns_true_for_focused_node |
| Element disappears | When exists=false | When | `ConditionPredicate.evaluate(resolutionResult:)` | test_exists_false_predicate_returns_true_when_resolver_returns_notFound |
| Value equality | When value changes | When | `ConditionPredicate.evaluate(node:)` | test_value_equality_predicate_handles_string_and_number, test_value_equality_is_case_sensitive |
| Malformed expression | When parse fails | When | `ConditionExpressionParser.parse(_:)` | test_parser_rejects_double_equals_chain, test_parser_rejects_unknown_field, test_error_lists_supported_fields_and_operators |
| Outline — every state field | When each field tested | When | `ConditionPredicate.evaluate(node:)` | test_predicate_handles_each_STORY_015_field |

---

## 6. TDD Unit Test Scaffolds

### 6.1 `ConditionExpressionParser` (new)

```swift
// FILE: Tests/MCP-MacOSControlTests/Accessibility/ConditionExpressionParserTests.swift
// STORY: STORY-009 — Element State Polling Tool
// COMPONENT: ConditionExpressionParser (parses "field = value" expressions)

import XCTest
@testable import MacOSControlLib

final class ConditionExpressionParserTests: XCTestCase {

    var parser: ConditionExpressionParser!

    override func setUp() {
        super.setUp()
        parser = ConditionExpressionParser()
    }

    // MARK: - Happy Path

    func test_parse_acceptsBooleanFields() throws {
        let cases: [(String, ConditionField, ConditionLiteral)] = [
            ("enabled = true",             .enabled,            .bool(true)),
            ("exists = false",             .exists,             .bool(false)),
            ("focused = true",             .focused,            .bool(true)),
            ("selected = true",            .selected,           .bool(true)),
            ("expanded = false",           .expanded,           .bool(false)),
            ("visible_in_viewport = true", .visibleInViewport,  .bool(true)),
            ("is_main = true",             .isMain,             .bool(true)),
            ("is_minimized = false",       .isMinimized,        .bool(false)),
            ("is_frontmost = true",        .isFrontmost,        .bool(true)),
        ]
        for (input, expectedField, expectedLiteral) in cases {
            let parsed = try parser.parse(input)
            XCTAssertEqual(parsed.field, expectedField, input)
            XCTAssertEqual(parsed.literal, expectedLiteral, input)
        }
    }

    func test_parse_acceptsValueStringEquality() throws {
        let parsed = try parser.parse("value = 'Connected'")
        XCTAssertEqual(parsed.field, .value)
        XCTAssertEqual(parsed.literal, .string("Connected"))
    }

    // MARK: - Error Paths

    func test_parse_rejectsDoubleEqualsChain() {
        XCTAssertThrowsError(try parser.parse("selected = banana = true")) { error in
            guard let err = error as? InvalidConditionExpressionError else {
                XCTFail("Expected InvalidConditionExpressionError"); return
            }
            XCTAssertTrue(err.supportedFields.contains("enabled"))
            XCTAssertTrue(err.supportedOperators.contains("="))
        }
    }

    func test_parse_rejectsUnknownField() {
        XCTAssertThrowsError(try parser.parse("magical = true")) { error in
            XCTAssertTrue(error is InvalidConditionExpressionError)
        }
    }

    func test_parse_rejectsEmptyExpression() {
        XCTAssertThrowsError(try parser.parse(""))
        XCTAssertThrowsError(try parser.parse("   "))
    }
}
```

### 6.2 `WaitForElementStateTool` (tool layer)

```swift
// FILE: Tests/MCP-MacOSControlTests/Modules/WaitForElementStateToolTests.swift
// STORY: STORY-009 — Element State Polling Tool
// COMPONENT: WaitForElementStateTool

import XCTest
@testable import MacOSControlLib

final class WaitForElementStateToolTests: XCTestCase {

    var tool: WaitForElementStateTool!
    var fakeResolver: FakeAXElementResolver!
    var fakeClock: FakeClock!

    override func setUp() {
        super.setUp()
        fakeResolver = FakeAXElementResolver()
        fakeClock = FakeClock()
        tool = WaitForElementStateTool(resolver: fakeResolver,
                                       clock: fakeClock,
                                       pollIntervalMs: 100)
    }

    // MARK: - Happy Path

    func test_execute_returnsSuccess_whenPredicateBecomesTrue() async throws {
        // Arrange — element starts disabled, becomes enabled on 3rd poll
        fakeResolver.stub([
            .found(makeFakeButton(enabled: false)),
            .found(makeFakeButton(enabled: false)),
            .found(makeFakeButton(enabled: true)),
        ])
        let input = WaitForElementStateInput(
            role: "AXButton", title: "Submit",
            condition: "enabled = true", timeoutSeconds: 5)
        // Act
        let result = await tool.execute(input: input)
        // Assert
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content["schema_version"] as? Int, 3)
        XCTAssertEqual((result.content["element"] as? [String: Any])?["enabled"] as? Bool, true)
    }

    func test_execute_returnsSuccess_whenElementAppears_existsTrue() async throws {
        fakeResolver.stub([
            .notFound, .notFound, .found(makeFakeList())
        ])
        let input = WaitForElementStateInput(
            role: "AXList", condition: "exists = true", timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertFalse(result.isError)
    }

    func test_execute_returnsSuccess_whenElementDisappears_existsFalse() async throws {
        fakeResolver.stub([
            .found(makeFakeSpinner()), .found(makeFakeSpinner()), .notFound
        ])
        let input = WaitForElementStateInput(
            role: "AXProgressIndicator", condition: "exists = false", timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content["exists"] as? Bool, false)
    }

    func test_execute_matchesStringValueEquality_caseSensitive() async throws {
        fakeResolver.stub([
            .found(makeFakeStatusLabel(value: "Connecting…")),
            .found(makeFakeStatusLabel(value: "Connected")),
        ])
        let input = WaitForElementStateInput(
            role: "AXStaticText", identifier: "status-label",
            condition: "value = 'Connected'", timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertFalse(result.isError)
    }

    // MARK: - Error Paths

    func test_execute_returnsStateConditionNotMetError_onTimeout() async {
        fakeResolver.stub(repeating: .found(makeFakeButton(enabled: false)), times: 50)
        let input = WaitForElementStateInput(
            role: "AXButton", title: "Submit",
            condition: "enabled = true", timeoutSeconds: 1)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "state_condition_not_met")
        XCTAssertNotNil(result.details["current_state"])
        XCTAssertNotNil(result.details["elapsed_seconds"])
    }

    func test_execute_returnsInvalidConditionExpressionError_onMalformedInput() async {
        let input = WaitForElementStateInput(
            role: "AXButton",
            condition: "selected = banana = true", timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "invalid_condition_expression")
    }

    func test_execute_rejectsTimeoutAboveCap() async {
        let input = WaitForElementStateInput(
            role: "AXButton", condition: "enabled = true", timeoutSeconds: 600)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "timeout_exceeds_maximum")
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Source | Notes |
|---|---|---|---|
| `AXElementResolver` | Real (STORY-001) | `FakeAXElementResolver` | Re-invoked every poll cycle |
| `AccessibilityTreeBuilder.buildShallow` | Real (STORY-004 §10) | No double | Single-node read; cheap enough for 100ms cadence |
| `AXNodeSerializer` (schema_version=3) | Real (STORY-015) | No double | Provides every state field this tool can predicate on |
| `ConditionExpressionParser` | **New** | No double — pure value type | Field set is closed and tied to STORY-015 |
| `Clock` | Abstraction over `DispatchTime` | `FakeClock` | Enables deterministic timeout tests |
| `ErrorCodeRegistry` (STORY-016) | Real | No double | Registers `state_condition_not_met`, `invalid_condition_expression`, `timeout_exceeds_maximum`, `accessibility_permission_required` |

---

## 8. Definition of Done

**Tool contract**
- [ ] `wait_for_element_state` registered in `ToolRouter` via `WaitForElementStateTool`
- [ ] Input schema: element locator fields (role, title, identifier, label — matching STORY-001 locator shape), `condition` (string, required, parsed by `ConditionExpressionParser`), `timeout_seconds` (number, default 30, max 120)
- [ ] Output schema on success: `{ element: <schema_version=3 node>, condition_met: true, elapsed_seconds, polls_performed }`
- [ ] Output schema on error: STORY-016 structured error contract
- [ ] `Tool.Annotations`: `readOnlyHint: true`, `idempotentHint: true`, `openWorldHint: true`

**Supported condition fields**
- [ ] All STORY-015 boolean fields: `enabled`, `exists`, `focused`, `selected`, `expanded`, `visible_in_viewport`, `is_main`, `is_minimized`, `is_frontmost`
- [ ] `value` (string equality, case-sensitive, exact match)
- [ ] Supported operators: `=` only at v1 (parser written to allow future `!=`, `~=` without rework)

**Polling discipline**
- [ ] Fixed 100ms polling interval (configurable via `MCP_MACOS_CONTROL_POLL_INTERVAL_MS`)
- [ ] Single in-flight resolver call per poll (no concurrent over-fetching)
- [ ] Polling halts immediately on first condition match; remaining time not consumed
- [ ] Final element shape captured at the moment of match (not stale from earlier poll)

**Error contract registered with STORY-016**
- [ ] Codes: `state_condition_not_met`, `invalid_condition_expression`, `timeout_exceeds_maximum`, `accessibility_permission_required`
- [ ] `state_condition_not_met` includes `current_state` (last serialized node) and `elapsed_seconds`

**Tests**
- [ ] All BDD scenarios pass in CI
- [ ] `ConditionExpressionParser` unit coverage 100%
- [ ] `WaitForElementStateTool` unit coverage ≥ 85%
- [ ] Living documentation generator maps every scenario to ≥ 1 unit test

**Documentation**
- [ ] `docs/stories/STORY-009-element-state-polling.md` (this file) committed
- [ ] `Tests/MCP-MacOSControlTests/Features/story-009-element-state-polling.feature` committed
- [ ] README "Tools" section updated with the new tool

---

## 9. Notes & Observations

- **Why bump from 2 to 3 points?** Round 4's STORY-009 supported only `enabled`/`exists`/`value` — three predicates, no parser, no scenarios for the structured state fields. STORY-015 (Round 5) shipped 6 additional boolean fields + window-state flags. Honoring those fields here requires a real expression parser and an outline-driven test matrix. That's a genuine scope increase, not a re-estimation.
- **Why is the timeout cap (120s) lower than STORY-008's (300s)?** Polling has steady CPU cost; event-driven waits cost ~nothing once subscribed. Encouraging long event-driven waits and short polling waits aligns the system with its own efficiency story.
- **Why no support for compound conditions (`enabled = true AND focused = true`) at v1?** The Cardinal Rule of BDD says one scenario, one behavior — and at the tool level, "one condition, one wait" is the analogous discipline. Compound predicates are easy to bolt on if real agent traces show the need; meanwhile they trade off complexity in the parser and ambiguity in the error reporting ("which clause failed?").
- **Interaction with STORY-008:** A common agent pattern will be: call STORY-008 for `AXValueChanged`, then call STORY-009 with the new value to confirm it's what we expected. This is good. The two tools compose cleanly because they share the schema_version=3 element shape.
