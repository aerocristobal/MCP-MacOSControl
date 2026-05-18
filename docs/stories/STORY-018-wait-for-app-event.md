# STORY-018 — Wait for Application Lifecycle Event Tool

**Epic:** EPIC-5 · Event-Driven Waiting & Observers
**Priority:** 🟡 High
**Story Points:** 2
**Sprint Target:** Sprint 3
**Dependencies:** 🔒 STORY-016 (Structured Error Response Contract)
**Refinement Round:** 6 — Newly added during Epic 5 refinement. Fills the documented Epic 5 goal-line "NSWorkspace notifications" that no prior story covered.

---

## 1. User Story Narrative

```
Story: Wait for Application Lifecycle Event Tool
In order to synchronize agent actions with the launch, activation, or termination of macOS applications
As an AI agent using the MCP server
I want a wait_for_app_event tool that subscribes to NSWorkspace notifications and returns when one fires
So that I can sequence "open app → first window appears → click" workflows without polling get_running_apps or screenshots
```

**Additional Context:** Epic 5's stated goal is to replace polling with "AXObserver event subscriptions **and NSWorkspace notifications**." STORY-008 covers AXObserver; STORY-013 uses NSWorkspace internally for the frontmost-app MCP Resource. But no story exposes NSWorkspace lifecycle events as a wait primitive to agents. The gap is concrete: AXObserver requires an already-running, AX-queryable target. Agents that issue "open Safari" via `run_applescript` (STORY-006) have no event-driven way to know when Safari is actually ready to receive AX queries. Their only options today are `wait_milliseconds` (brittle) or `wait_for_text` (screenshot-based, expensive). This tool closes that loop. Independently of STORY-008/STORY-009, it depends on STORY-016's error contract only — making it the cheapest Epic 5 story to ship.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-5 @story-018 @mcp-tool
Feature: Wait for Application Lifecycle Event Tool
  In order to react to macOS application lifecycle changes without polling
  As an AI agent
  I want wait_for_app_event to subscribe to an NSWorkspace notification and return when it fires

  Background:
    Given the MCP server is running

  Scenario: Wait resolves when a named application launches
    Given the application "Calculator" is not currently running
    When the AI agent calls wait_for_app_event with event "launched" for bundle_id "com.apple.calculator"
    And "Calculator" is launched by any means
    Then the tool returns a success response
    And the response includes "bundle_identifier": "com.apple.calculator"
    And the response includes the launched app's pid and localized name
    And the response includes "interaction_method": "nsworkspace_observer"

  Scenario: Wait resolves when an application becomes frontmost
    Given "TextEdit" is running but is not the frontmost application
    When the AI agent calls wait_for_app_event with event "activated" for bundle_id "com.apple.TextEdit"
    And "TextEdit" is brought to the foreground
    Then the tool returns a success response
    And the response indicates "TextEdit" is now frontmost

  Scenario: Wait resolves when an application terminates
    Given "TextEdit" is running
    When the AI agent calls wait_for_app_event with event "terminated" for bundle_id "com.apple.TextEdit"
    And "TextEdit" quits
    Then the tool returns a success response
    And the response includes the terminated app's bundle identifier and exit reason if available

  Scenario: Wait resolves on the next launch when no bundle_id filter is given
    Given the AI agent omits bundle_id and uses event "launched"
    When any application is launched by any means
    Then the tool returns a success response describing that application

  Scenario: Wait times out if the lifecycle event never fires
    Given "Calculator" is not running and will not be launched within the test window
    When the AI agent calls wait_for_app_event with event "launched" bundle_id "com.apple.calculator" and timeout 2 seconds
    And no matching event fires within 2 seconds
    Then the tool returns a structured error with error_code "wait_timeout"
    And the error details include the event name, bundle_id filter, and elapsed seconds
    But no NSWorkspace observer remains registered for the call

  Scenario: Reject unsupported event name
    When the AI agent calls wait_for_app_event with event "hibernated"
    Then the tool returns a structured error with error_code "unsupported_app_event"
    And the error details list the supported event names

  Scenario: Reject malformed bundle identifier
    When the AI agent calls wait_for_app_event with event "launched" and bundle_id "not a bundle id"
    Then the tool returns a structured error with error_code "invalid_bundle_identifier"

  Scenario Outline: Support every NSWorkspace lifecycle notification
    When the AI agent calls wait_for_app_event with event <event>
    And an application triggers <event> by any means
    Then the tool returns a success response within the timeout

    Examples:
      | event       |
      | launched    |
      | activated   |
      | terminated  |
      | deactivated |
      | hidden      |
      | unhidden    |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | Calculator launches | ✅ |
| Alternative success path | App activates, terminates, no-filter wildcard | ✅ |
| Boundary condition | Outline across the full NSWorkspace event set | ✅ |
| Error / rejection path | Timeout; unsupported event; malformed bundle_id | ✅ |
| Business rule edge case | Wildcard (no bundle_id) wait returns first matching app of any identity | ✅ |

---

## 4. Three Amigos Open Questions

| # | Question | Resolution |
|---|---|---|
| Q1 | Event name vocabulary — should we use the raw `NS…NotificationName` constants or friendly names? | **Friendly names** (`launched`, `activated`, `terminated`, `deactivated`, `hidden`, `unhidden`). Raw NS constants leak Apple SDK specifics into the agent's prompt vocabulary. Mapping is internal. _[NEEDS CONFIRMATION]_ |
| Q2 | Wildcard wait (`event: launched` with no `bundle_id`) — useful or footgun? | **Keep.** Useful for "wait until anything launches after I trigger something via Spotlight." Footgun mitigated by reasonable defaults (must specify event; timeout caps still apply). |
| Q3 | What is the maximum allowed `timeout_seconds`? | **300 seconds.** Same cap as STORY-008; NSWorkspace observers have negligible steady-state cost. _[NEEDS CONFIRMATION]_ |
| Q4 | Should concurrent waiters for the same `(event, bundle_id)` share one underlying NSWorkspace observer? | **Yes — fan-out from a single observer.** Same architectural choice as STORY-008 Q1. STORY-013 already uses one shared NSWorkspace observer for the frontmost-app resource; this story reuses the pattern. _[NEEDS CONFIRMATION: confirm sharing between STORY-013 and STORY-018 is desired or kept separate]_ |
| Q5 | If the app is already in the desired state at subscription time (e.g., waiting for `activated` and the app is already frontmost), do we resolve immediately or only on the next transition? | **Resolve only on next transition.** A wait tool's contract is to wait for an event, not to inspect current state. Callers who want to check current state should use `list_windows` or an `accessibility_tree` snapshot first. |
| Q6 | Bundle identifier validation strictness | **Apple's reverse-DNS pattern** (`^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$`). Reject anything that won't parse as a bundle id before subscribing. |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| Calculator launches | When tool called | When | `WaitForAppEventTool.execute(input:)` | test_subscribes_via_workspace_observer, test_resolves_when_NSDidLaunchApplication_fires |
| Calculator launches | Then response shape | Then | `WaitForAppEventTool` response builder | test_response_includes_bundle_id_pid_name_interaction_method |
| TextEdit activates | When activated | When | `NSWorkspaceEventBridge.observe(_:)` | test_dispatches_NSDidActivateApplication_to_subscribers |
| TextEdit terminates | When terminates | When | `NSWorkspaceEventBridge.observe(_:)` | test_dispatches_NSDidTerminateApplication_to_subscribers |
| Wildcard wait | When any app launches | When | `WaitForAppEventTool` filtering | test_no_bundle_id_filter_matches_first_event |
| Timeout | When event never fires | When | `NSWorkspaceEventBridge.wait(...)` | test_returns_WaitTimeoutError_after_deadline, test_unregisters_observer_on_timeout |
| Unsupported event | When invalid name | When | `WaitForAppEventTool` input validation | test_rejects_unknown_event_name, test_error_lists_supported_event_names |
| Malformed bundle_id | When invalid format | When | `BundleIdentifierValidator.validate(_:)` | test_validator_accepts_reverseDNS, test_validator_rejects_spaces_and_invalid_chars |
| Outline — every event | Each event variant | When | `NSWorkspaceEventBridge.observe(_:)` | test_dispatches_each_supported_event_variant |

---

## 6. TDD Unit Test Scaffolds

### 6.1 `NSWorkspaceEventBridge` (new)

```swift
// FILE: Tests/MCP-MacOSControlTests/Accessibility/NSWorkspaceEventBridgeTests.swift
// STORY: STORY-018 — Wait for Application Lifecycle Event Tool
// COMPONENT: NSWorkspaceEventBridge

import XCTest
@testable import MacOSControlLib

final class NSWorkspaceEventBridgeTests: XCTestCase {

    var bridge: NSWorkspaceEventBridge!
    var fakeWorkspace: FakeNotificationCenter!

    override func setUp() {
        super.setUp()
        fakeWorkspace = FakeNotificationCenter()
        bridge = NSWorkspaceEventBridge(notificationCenter: fakeWorkspace)
    }

    // MARK: - Happy Path

    func test_wait_resolvesWhenLaunchNotificationFires() async throws {
        async let result = bridge.wait(
            event: .launched, bundleIdentifierFilter: "com.apple.calculator", timeout: 5)
        try await Task.sleep(nanoseconds: 50_000_000)
        fakeWorkspace.fireLaunched(bundleId: "com.apple.calculator", pid: 4321, name: "Calculator")
        let event = try await result
        XCTAssertEqual(event.bundleIdentifier, "com.apple.calculator")
        XCTAssertEqual(event.pid, 4321)
        XCTAssertEqual(event.eventType, .launched)
    }

    func test_wait_resolvesOnWildcard_whenBundleIdFilterIsNil() async throws {
        async let result = bridge.wait(event: .launched, bundleIdentifierFilter: nil, timeout: 5)
        try await Task.sleep(nanoseconds: 50_000_000)
        fakeWorkspace.fireLaunched(bundleId: "com.example.random", pid: 9999, name: "Random")
        let event = try await result
        XCTAssertEqual(event.bundleIdentifier, "com.example.random")
    }

    func test_wait_ignoresMismatchedBundleId() async throws {
        async let result = bridge.wait(
            event: .launched, bundleIdentifierFilter: "com.apple.calculator", timeout: 0.5)
        try await Task.sleep(nanoseconds: 50_000_000)
        fakeWorkspace.fireLaunched(bundleId: "com.different.app", pid: 1234, name: "Different")
        // Should NOT resolve from mismatched event, should time out
        do {
            _ = try await result
            XCTFail("Expected WaitTimeoutError")
        } catch is WaitTimeoutError { /* expected */ }
        catch { XCTFail("Unexpected error: \(error)") }
    }

    // MARK: - Error Paths

    func test_wait_throwsWaitTimeoutError_whenNoEventFires() async {
        do {
            _ = try await bridge.wait(event: .terminated, bundleIdentifierFilter: nil, timeout: 0.1)
            XCTFail("Expected WaitTimeoutError")
        } catch let error as WaitTimeoutError {
            XCTAssertEqual(error.notification, "NSWorkspaceDidTerminateApplication")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Leak Prevention

    func test_wait_unregistersObserver_onTimeout() async {
        _ = try? await bridge.wait(event: .launched, bundleIdentifierFilter: nil, timeout: 0.05)
        XCTAssertEqual(fakeWorkspace.removeObserverCallCount, 1)
    }

    func test_wait_unregistersObserver_onResolve() async throws {
        async let result = bridge.wait(event: .launched, bundleIdentifierFilter: nil, timeout: 5)
        try await Task.sleep(nanoseconds: 50_000_000)
        fakeWorkspace.fireLaunched(bundleId: "com.apple.calculator", pid: 1, name: "Calc")
        _ = try await result
        XCTAssertEqual(fakeWorkspace.removeObserverCallCount, 1)
    }
}
```

### 6.2 `WaitForAppEventTool` (tool layer)

```swift
// FILE: Tests/MCP-MacOSControlTests/Modules/WaitForAppEventToolTests.swift
// STORY: STORY-018 — Wait for Application Lifecycle Event Tool
// COMPONENT: WaitForAppEventTool

import XCTest
@testable import MacOSControlLib

final class WaitForAppEventToolTests: XCTestCase {

    var tool: WaitForAppEventTool!
    var fakeBridge: FakeNSWorkspaceEventBridge!

    override func setUp() {
        super.setUp()
        fakeBridge = FakeNSWorkspaceEventBridge()
        tool = WaitForAppEventTool(bridge: fakeBridge)
    }

    // MARK: - Input Validation

    func test_execute_rejectsUnsupportedEventName() async {
        let input = WaitForAppEventInput(event: "hibernated",
                                         bundleIdentifier: "com.apple.calculator",
                                         timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "unsupported_app_event")
        let supported = result.details["supported_events"] as? [String] ?? []
        XCTAssertTrue(supported.contains("launched"))
    }

    func test_execute_rejectsMalformedBundleIdentifier() async {
        let input = WaitForAppEventInput(event: "launched",
                                         bundleIdentifier: "not a bundle id",
                                         timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "invalid_bundle_identifier")
    }

    func test_execute_rejectsTimeoutAboveCap() async {
        let input = WaitForAppEventInput(event: "launched", timeoutSeconds: 600)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "timeout_exceeds_maximum")
    }

    // MARK: - Happy Path

    func test_execute_returnsSuccessResponse_includingInteractionMethod() async {
        fakeBridge.stubbedEvent = AppLifecycleEvent(
            eventType: .launched,
            bundleIdentifier: "com.apple.calculator",
            pid: 4321,
            localizedName: "Calculator")
        let input = WaitForAppEventInput(event: "launched",
                                         bundleIdentifier: "com.apple.calculator",
                                         timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content["bundle_identifier"] as? String, "com.apple.calculator")
        XCTAssertEqual(result.content["pid"] as? Int, 4321)
        XCTAssertEqual(result.content["interaction_method"] as? String, "nsworkspace_observer")
    }
}
```

### 6.3 `BundleIdentifierValidator` (new — small pure value type)

```swift
// FILE: Tests/MCP-MacOSControlTests/Accessibility/BundleIdentifierValidatorTests.swift
// STORY: STORY-018 — Wait for Application Lifecycle Event Tool
// COMPONENT: BundleIdentifierValidator

import XCTest
@testable import MacOSControlLib

final class BundleIdentifierValidatorTests: XCTestCase {

    func test_validator_acceptsReverseDNS() throws {
        XCTAssertNoThrow(try BundleIdentifierValidator.validate("com.apple.calculator"))
        XCTAssertNoThrow(try BundleIdentifierValidator.validate("io.example.long-name"))
        XCTAssertNoThrow(try BundleIdentifierValidator.validate("a.b"))
    }

    func test_validator_rejectsSpaces() {
        XCTAssertThrowsError(try BundleIdentifierValidator.validate("com apple calculator"))
    }

    func test_validator_rejectsSingleToken() {
        XCTAssertThrowsError(try BundleIdentifierValidator.validate("calculator"))
    }

    func test_validator_rejectsEmpty() {
        XCTAssertThrowsError(try BundleIdentifierValidator.validate(""))
    }

    func test_validator_rejectsInvalidChars() {
        XCTAssertThrowsError(try BundleIdentifierValidator.validate("com.apple.calc/utility"))
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Source | Notes |
|---|---|---|---|
| `NSWorkspace.shared.notificationCenter` | Real | `FakeNotificationCenter` | Single shared observer, fanned out to N waiters |
| `BundleIdentifierValidator` | **New**, pure value type | No double | Reverse-DNS regex |
| `Clock` | Abstraction | `FakeClock` | Deterministic timeout tests |
| `ErrorCodeRegistry` (STORY-016) | Real | No double | Registers `wait_timeout`, `unsupported_app_event`, `invalid_bundle_identifier`, `timeout_exceeds_maximum` |

---

## 8. Definition of Done

**Tool contract**
- [ ] `wait_for_app_event` registered in `ToolRouter` via `WaitForAppEventTool`
- [ ] Input schema: `event` (enum: `launched`, `activated`, `terminated`, `deactivated`, `hidden`, `unhidden`), `bundle_identifier` (string, optional), `timeout_seconds` (number, default 30, max 300)
- [ ] Output on success: `{ event_type, bundle_identifier, pid, localized_name, interaction_method: "nsworkspace_observer", elapsed_seconds }`
- [ ] Output on error: STORY-016 structured error contract
- [ ] `Tool.Annotations`: `readOnlyHint: true`, `idempotentHint: false`, `openWorldHint: true`

**Subscription correctness**
- [ ] One underlying `NSWorkspace.shared.notificationCenter` observer per `(event, bundle_id_filter)` tuple, fan-out to N concurrent waiters
- [ ] Observer is `removeObserver`'d on every termination path: fire, timeout, error
- [ ] Stress test: 100 sequential timeouts shows zero residual observers
- [ ] If both STORY-013 and STORY-018 ship, no double-subscription on the shared frontmost-app notification (verified by integration test)

**Error contract registered with STORY-016**
- [ ] `wait_timeout` (shared code with STORY-008 — confirmed via `ErrorCodeRegistry` collision check)
- [ ] `unsupported_app_event` (includes `supported_events` in details)
- [ ] `invalid_bundle_identifier` (includes `bundle_identifier_pattern` in details)
- [ ] `timeout_exceeds_maximum`

**Tests**
- [ ] All BDD scenarios pass in CI
- [ ] `NSWorkspaceEventBridge` unit coverage ≥ 85%
- [ ] `WaitForAppEventTool` unit coverage ≥ 85%
- [ ] `BundleIdentifierValidator` unit coverage 100%
- [ ] Living documentation generator maps every scenario to ≥ 1 unit test

**Documentation**
- [ ] `docs/stories/STORY-018-wait-for-app-event.md` (this file) committed
- [ ] `Tests/MCP-MacOSControlTests/Features/story-018-wait-for-app-event.feature` committed
- [ ] README "Tools" section updated
- [ ] An entry added to the `interaction_hierarchy` MCP Prompt (STORY-017) describing when to prefer `wait_for_app_event` over `wait_for_ui_event`

---

## 9. Notes & Observations

- **Why a new story instead of expanding STORY-008?** AXObserver and NSWorkspace are different observation systems with different scoping rules. AXObserver requires a target `AXUIElement` (i.e. an already-launched app). NSWorkspace is global and pre-launch capable. Stuffing both into one tool makes the input schema confusing and produces a Frankenstein scenario set. Separate tools, shared conventions (`interaction_method`, error codes), reusable infrastructure where it makes sense (the NSWorkspace termination observer used by STORY-008 Q1 can be a façade over the same bridge).
- **Why is this 2 points?** No new AX C-API wrapping; `NSWorkspace.notificationCenter` is a clean Cocoa API. Most of the work is the input validation, the small bridge actor, and the test matrix.
- **Sequencing with STORY-008:** Independently shippable. STORY-018 depends on STORY-016 only. If sprint capacity is tight, STORY-018 is the cheapest Epic 5 ticket to ship and immediately unlocks the "open Safari → wait until ready" workflow that's brittle today.
- **STORY-012 (integration suite) integration:** The Round 4 scenario "Complete agent workflow — open, type, save a document" begins with `run_applescript` to open TextEdit, then `wait_for_ui_event` for `AXWindowCreated`. With STORY-018 shipped, the more correct opening would be `wait_for_app_event launched bundle_id=com.apple.TextEdit`, then `wait_for_ui_event AXWindowCreated`. Worth adding as an additional STORY-012 scenario when both ship.
- **Why not also support `NSWorkspaceWillLaunchApplicationNotification`?** That fires before the app's process is fully ready for AX queries. Agents waiting for "the app is launchable" actually mean "the app is ready" — so `didLaunch` is the right primitive. `willLaunch` could be added later if a real use case emerges.
