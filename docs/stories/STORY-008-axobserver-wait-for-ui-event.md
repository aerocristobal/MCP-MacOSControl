# STORY-008 — AXObserver Wait for UI Event Tool

**Epic:** EPIC-5 · Event-Driven Waiting & Observers
**Priority:** 🟡 High
**Story Points:** 5
**Sprint Target:** Sprint 3
**Dependencies:** 🔒 STORY-001 (AXElementResolver), 🔒 STORY-004 (Enhanced AX Tree), 🔒 STORY-016 (Structured Error Response Contract)
**Refinement Round:** 6 — Epic 5 expansion. Scenarios 4 → 9; DoD bullets reorganized; resolved Three Amigos open questions §4; Round 5 schema_version=3 alignment added.

---

## 1. User Story Narrative

```
Story: AXObserver Wait for UI Event Tool
In order to synchronize agent actions with UI state changes without polling
As an AI agent using the MCP server
I want a wait_for_ui_event tool that subscribes to AXObserver notifications and blocks until one fires
So that I can replace fixed sleeps and screenshot-polling with precise event-driven synchronization
```

**Additional Context:** This is the centerpiece of Epic 5's "AXObserver event subscriptions" goal. The tool wraps the C-level Accessibility Observer API (`AXObserverCreate`, `AXObserverAddNotification`, `AXObserverGetRunLoopSource`) behind a request/response MCP contract. Implementation must guarantee observer lifecycle correctness — a leaked observer holds a CFRunLoopSource and can crash the server when the target process terminates. The tool reduces token waste in agent workflows (no repeated `accessibility_tree` calls), reduces wall-clock time (no fixed sleeps), and is a prerequisite for STORY-010's interaction-hierarchy router to know when an action's effect has actually landed in the UI.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-5 @story-008 @mcp-tool
Feature: AXObserver Wait for UI Event Tool
  In order to react to UI state changes without polling
  As an AI agent
  I want wait_for_ui_event to subscribe to an AXObserver notification and return when it fires

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  # --- Round 4 scenarios (preserved) ---

  Scenario: Wait resolves when a window appears
    Given "TextEdit" is open with no dialogs visible
    When the AI agent calls wait_for_ui_event with notification "AXWindowCreated" for application "TextEdit"
    And a new TextEdit window is opened by any means
    Then the tool returns a success response containing the new window's element shape
    And the response includes "schema_version": 3
    And the response includes "interaction_method": "ax_observer"

  Scenario: Wait resolves when a sheet is dismissed
    Given a Save sheet is displayed in "TextEdit"
    When the AI agent calls wait_for_ui_event with notification "AXUIElementDestroyed" targeting the sheet element
    And the sheet is dismissed
    Then the tool returns a success response
    And the response indicates the destroyed element's prior AXIdentifier

  Scenario: Wait times out if event does not occur within the specified duration
    Given "TextEdit" is open with no pending UI changes
    When the AI agent calls wait_for_ui_event with notification "AXWindowCreated" and timeout 3 seconds
    And no new window is created within 3 seconds
    Then the tool returns a structured error with error_code "wait_timeout"
    And the error details include the notification name and elapsed seconds
    But no AXObserver remains registered for the call

  Scenario: Wait resolves when focused element changes
    Given a form with multiple fields is visible in "TextEdit"
    When the AI agent calls wait_for_ui_event with notification "AXFocusedUIElementChanged" for application "TextEdit"
    And focus moves to a different field
    Then the tool returns a success response
    And the response includes the new focused element's role, title, and AXIdentifier

  # --- Round 6 additions: lifecycle, error paths, and concurrency ---

  Scenario: Observer is unregistered when the target application terminates mid-wait
    Given "TextEdit" is open
    And the AI agent has called wait_for_ui_event for notification "AXValueChanged" in "TextEdit" with timeout 30 seconds
    When "TextEdit" terminates before the notification fires
    Then the tool returns a structured error with error_code "target_application_terminated"
    And the error details include the terminated application's bundle identifier
    But no orphaned AXObserver or CFRunLoopSource remains in the server process

  Scenario: Two concurrent waits on the same notification both resolve when it fires
    Given two AI agents have independently called wait_for_ui_event for "AXWindowCreated" in "TextEdit"
    When a new TextEdit window is opened by any means
    Then both tool calls return a success response describing the same new window
    And only one underlying AXObserver was registered for the (TextEdit, AXWindowCreated) pair
    And the underlying AXObserver is unregistered after the last waiter resolves

  Scenario: Permission denied at subscription time returns a structured error
    Given accessibility permissions have been revoked from the MCP process
    When the AI agent calls wait_for_ui_event for any notification in any application
    Then the tool returns a structured error with error_code "accessibility_permission_required"
    And no AXObserver is created
    And the error message describes how to grant accessibility permissions

  Scenario: Unsupported notification name returns a structured error
    Given "TextEdit" is open
    When the AI agent calls wait_for_ui_event with notification "AXMadeUpNotification" for application "TextEdit"
    Then the tool returns a structured error with error_code "unsupported_notification"
    And the error details list the supported notification names

  Scenario Outline: Support the documented AX notification set
    Given "TextEdit" is open
    When the AI agent calls wait_for_ui_event with notification <notification>
    And the corresponding UI event is triggered in TextEdit
    Then the tool returns a success response within the timeout
    And the response includes the element shape relevant to <notification>

    Examples:
      | notification                |
      | AXWindowCreated             |
      | AXUIElementDestroyed        |
      | AXFocusedUIElementChanged   |
      | AXValueChanged              |
      | AXSelectedTextChanged       |
      | AXTitleChanged              |
      | AXMainWindowChanged         |
      | AXFocusedWindowChanged      |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | Window appears; focused element changes | ✅ |
| Alternative success path | Sheet dismissed; concurrent waiters fan-out | ✅ |
| Boundary condition | Timeout at exact duration; outline covers full notification set | ✅ |
| Error / rejection path | Timeout; app terminated; permission revoked; unsupported notification | ✅ |
| Business rule edge case | Observer leak prevention on early termination; multiplexed subscribers | ✅ |

---

## 4. Three Amigos Open Questions (Round 6)

| # | Question | Resolution |
|---|---|---|
| Q1 | When two MCP calls subscribe to the same (app, notification), do we register one or two underlying AXObservers? | **One.** Recommended: an `AXObserverManager` actor multiplexes N MCP waiters onto 1 underlying `AXObserver` per `(pid, notification)`. Reduces system overhead; matches STORY-013's NSWorkspace pattern. _[NEEDS CONFIRMATION: validated by Three Amigos]_ |
| Q2 | If the target application terminates mid-wait, do we return success-with-null or a structured error? | **Structured error** `target_application_terminated`. Success-with-null forces every agent to add a "was the app still alive?" check; the explicit error is more honest. _[NEEDS CONFIRMATION]_ |
| Q3 | What is the maximum allowed `timeout_seconds`? | **300 seconds (5 min) hard cap.** Anything longer should use STORY-013's MCP Resources subscription pattern instead. _[NEEDS CONFIRMATION]_ |
| Q4 | If an element targeted by `element_locator` doesn't exist at subscription time, do we wait for it to appear first or return an error? | **Return error** `element_not_found`. Waiting for an element to appear is STORY-009's job (`wait_for_element_state` with `exists=true`). One tool, one behavior. |
| Q5 | Can the agent cancel a pending wait before timeout? | **Deferred.** Cross-cutting concern with STORY-009 and STORY-018. MCP protocol-level cancellation (`notifications/cancelled`) should be the answer at the server layer, not in any single wait tool. Track separately. |
| Q6 | Element shape returned for `AXUIElementDestroyed` — full shape or just identifier? | **Identifier + role + title cached from subscription time.** The element is destroyed by the time the notification fires; reading attributes from a dead AXUIElement is undefined. Cache at subscription. _[NEEDS CONFIRMATION]_ |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| Window appears | Given app open | Given | `AXApplicationBridge` (existing from STORY-001) | reuse |
| Window appears | When wait called | When | `WaitForUIEventTool.execute(input:)` | test_subscribes_via_manager, test_returns_success_when_notification_fires |
| Window appears | Then response shape | Then | `AXNodeSerializer` (existing) | reuse from STORY-015 |
| Timeout | When no event in time | When | `AXObserverManager.wait(for:in:timeout:)` | test_cancels_subscription_after_timeout, test_returns_WaitTimeoutError_with_details |
| App terminated | When app quits mid-wait | When | `AXObserverManager` + `NSWorkspace` observer integration | test_returns_TargetTerminatedError_when_NSWorkspace_didTerminate_fires, test_no_orphaned_runloop_source |
| Concurrent waiters | When second waiter joins | When | `AXObserverManager.wait(for:in:timeout:)` | test_multiplexes_two_callers_onto_one_AXObserver, test_unregisters_observer_after_last_waiter |
| Permission denied | Given perms revoked | Given | `AXObserverManager.canSubscribe()` | test_returns_PermissionError_when_AXIsProcessTrusted_false |
| Unsupported notification | When unknown name passed | When | `WaitForUIEventTool.execute(input:)` validation | test_rejects_unknown_notification, test_lists_supported_notifications_in_error |
| Notification set outline | Each notification | When | `AXObserverManager.wait(for:in:timeout:)` | test_dispatches_each_supported_notification_constant |
| Focused element changed | Then response includes new focus | Then | `WaitForUIEventTool` response builder | test_response_includes_role_title_identifier_for_focused_element |
| Destroyed element | Then response uses cached attributes | Then | `AXObserverManager.cacheAttributes(of:)` | test_caches_role_title_identifier_at_subscription_time |

---

## 6. TDD Unit Test Scaffolds

### 6.1 `AXObserverManager` (new — Epic 5 foundation)

```swift
// FILE: Tests/MCP-MacOSControlTests/Accessibility/AXObserverManagerTests.swift
// STORY: STORY-008 — AXObserver Wait for UI Event Tool
// COMPONENT: AXObserverManager (multiplexed subscription manager)

import XCTest
@testable import MacOSControlLib

final class AXObserverManagerTests: XCTestCase {

    var manager: AXObserverManager!
    var fakeAXBridge: FakeAXObserverBridge!
    var fakeWorkspace: FakeNSWorkspaceObserver!

    override func setUp() {
        super.setUp()
        fakeAXBridge = FakeAXObserverBridge()
        fakeWorkspace = FakeNSWorkspaceObserver()
        manager = AXObserverManager(axBridge: fakeAXBridge, workspace: fakeWorkspace)
    }

    // MARK: - Happy Path

    func test_wait_returnsSuccess_whenNotificationFires() async throws {
        // Arrange
        let pid: pid_t = 1234
        // Act
        async let result = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        try await Task.sleep(nanoseconds: 50_000_000)
        fakeAXBridge.fireNotification("AXWindowCreated", for: pid, element: makeFakeElement())
        // Assert
        let event = try await result
        XCTAssertEqual(event.notification, "AXWindowCreated")
    }

    // MARK: - Subscription Multiplexing

    func test_wait_multiplexesTwoCallers_ontoOneUnderlyingObserver() async throws {
        // Arrange
        let pid: pid_t = 1234
        // Act — two concurrent waiters
        async let r1 = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        async let r2 = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        try await Task.sleep(nanoseconds: 50_000_000)
        // Assert — only one observer created
        XCTAssertEqual(fakeAXBridge.observerCreateCallCount, 1)
        // Fire and both resolve
        fakeAXBridge.fireNotification("AXWindowCreated", for: pid, element: makeFakeElement())
        _ = try await (r1, r2)
    }

    func test_wait_unregistersObserver_afterLastWaiterResolves() async throws {
        // Arrange
        let pid: pid_t = 1234
        // Act
        async let r1 = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        try await Task.sleep(nanoseconds: 50_000_000)
        fakeAXBridge.fireNotification("AXWindowCreated", for: pid, element: makeFakeElement())
        _ = try await r1
        // Assert
        XCTAssertEqual(fakeAXBridge.observerRemoveCallCount, 1)
    }

    // MARK: - Error Paths

    func test_wait_throwsWaitTimeoutError_whenDeadlineElapses() async {
        // Arrange
        let pid: pid_t = 1234
        // Act + Assert
        do {
            _ = try await manager.wait(for: "AXWindowCreated", in: pid, timeout: 0.1)
            XCTFail("Expected WaitTimeoutError")
        } catch let error as WaitTimeoutError {
            XCTAssertEqual(error.notification, "AXWindowCreated")
            XCTAssertGreaterThanOrEqual(error.elapsedSeconds, 0.1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_wait_throwsTargetTerminatedError_whenAppQuitsMidWait() async {
        // Arrange
        let pid: pid_t = 1234
        // Act
        async let result = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        try? await Task.sleep(nanoseconds: 50_000_000)
        fakeWorkspace.fireTerminated(pid: pid, bundleId: "com.apple.TextEdit")
        // Assert
        do {
            _ = try await result
            XCTFail("Expected TargetApplicationTerminatedError")
        } catch let error as TargetApplicationTerminatedError {
            XCTAssertEqual(error.bundleIdentifier, "com.apple.TextEdit")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_wait_throwsPermissionError_whenAXNotTrusted() async {
        // Arrange
        fakeAXBridge.isProcessTrusted = false
        // Act + Assert
        do {
            _ = try await manager.wait(for: "AXWindowCreated", in: 1234, timeout: 5)
            XCTFail("Expected AccessibilityPermissionRequiredError")
        } catch is AccessibilityPermissionRequiredError {
            XCTAssertEqual(fakeAXBridge.observerCreateCallCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Leak Prevention

    func test_wait_doesNotLeakRunLoopSource_onTimeout() async {
        // Arrange
        let pid: pid_t = 1234
        // Act
        _ = try? await manager.wait(for: "AXWindowCreated", in: pid, timeout: 0.05)
        // Assert
        XCTAssertEqual(fakeAXBridge.observerRemoveCallCount, 1)
        XCTAssertEqual(fakeAXBridge.runLoopSourceRemovalCount, 1)
    }
}
```

### 6.2 `WaitForUIEventTool` (tool layer)

```swift
// FILE: Tests/MCP-MacOSControlTests/Modules/WaitForUIEventToolTests.swift
// STORY: STORY-008 — AXObserver Wait for UI Event Tool
// COMPONENT: WaitForUIEventTool (MCP tool surface)

import XCTest
@testable import MacOSControlLib

final class WaitForUIEventToolTests: XCTestCase {

    var tool: WaitForUIEventTool!
    var fakeManager: FakeAXObserverManager!
    var fakeResolver: FakeAXElementResolver!

    override func setUp() {
        super.setUp()
        fakeManager = FakeAXObserverManager()
        fakeResolver = FakeAXElementResolver()
        tool = WaitForUIEventTool(observerManager: fakeManager, resolver: fakeResolver)
    }

    // MARK: - Input Validation

    func test_execute_rejectsUnknownNotification_withSupportedList() async {
        let input = WaitForUIEventInput(notification: "AXMadeUpNotification",
                                        application: "TextEdit",
                                        timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "unsupported_notification")
        XCTAssertTrue(result.details["supported_notifications"]?.contains("AXWindowCreated") ?? false)
    }

    func test_execute_rejectsTimeoutAboveCap() async {
        let input = WaitForUIEventInput(notification: "AXWindowCreated",
                                        application: "TextEdit",
                                        timeoutSeconds: 600)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "timeout_exceeds_maximum")
    }

    // MARK: - Happy Path

    func test_execute_returnsSchemaVersion3_inSuccessResponse() async throws {
        fakeManager.stubbedEvent = .windowCreated(makeFakeElement())
        let input = WaitForUIEventInput(notification: "AXWindowCreated",
                                        application: "TextEdit",
                                        timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content["schema_version"] as? Int, 3)
        XCTAssertEqual(result.content["interaction_method"] as? String, "ax_observer")
    }

    // MARK: - Element-Locator Path

    func test_execute_returnsElementNotFoundError_whenLocatorDoesNotResolve() async {
        fakeResolver.stubbedError = AXNotFoundError(searchCriteria: "role=AXSheet")
        let input = WaitForUIEventInput(notification: "AXUIElementDestroyed",
                                        application: "TextEdit",
                                        elementLocator: ElementLocator(role: "AXSheet"),
                                        timeoutSeconds: 5)
        let result = await tool.execute(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "element_not_found")
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Source | Notes |
|---|---|---|---|
| `AXElementResolver` | Real (from STORY-001) | Test double: `FakeAXElementResolver` | Used only when `element_locator` is supplied |
| `AXNodeSerializer` | Real (from STORY-004/015) | No double | Element shape must be schema_version=3 |
| `AXObserverManager` | **New** — produced by this story | Test double: `FakeAXObserverManager` | Wraps `AXObserverCreate`/`AXObserverAddNotification` |
| `NSWorkspace.notificationCenter` | Real | Test double: `FakeNSWorkspaceObserver` | Required for app-terminated detection |
| `ErrorCodeRegistry` (STORY-016) | Real | No double | Registers `wait_timeout`, `target_application_terminated`, `accessibility_permission_required`, `unsupported_notification`, `element_not_found`, `timeout_exceeds_maximum` at startup |

---

## 8. Definition of Done

**Tool contract**
- [ ] `wait_for_ui_event` registered in `ToolRouter` via a new `WaitForUIEventModule`
- [ ] Input schema: `notification` (string, required), `application` (string, required), `element_locator` (optional — uses STORY-001 locator shape), `timeout_seconds` (number, default 30, max 300)
- [ ] Output schema on success: `{ notification, element: <schema_version=3 node>, interaction_method: "ax_observer", elapsed_seconds }`
- [ ] Output schema on error: STORY-016 structured error contract `{ error_code, message, details, isError: true }`
- [ ] `Tool.Annotations`: `readOnlyHint: true`, `idempotentHint: false`, `openWorldHint: true`

**Supported notification set** (matches STORY-012 integration scenarios)
- [ ] `AXWindowCreated`, `AXUIElementDestroyed`, `AXFocusedUIElementChanged`, `AXValueChanged`, `AXSelectedTextChanged`, `AXTitleChanged`, `AXMainWindowChanged`, `AXFocusedWindowChanged`
- [ ] List exported via the MCP Prompts primitive (STORY-017) under prompt `ax_observer_notifications`

**Observer lifecycle correctness**
- [ ] `AXObserverManager` actor multiplexes N MCP waiters onto 1 underlying `AXObserver` per `(pid, notification)`
- [ ] CFRunLoopSource is added on subscribe, removed on last-waiter-resolution
- [ ] `NSWorkspace.didTerminateApplicationNotification` registered for every active subscription; triggers immediate error to all waiters for that pid
- [ ] No orphaned `AXObserver` or `CFRunLoopSource` after any termination path (timeout, fire, app-quit, permission-revoke)
- [ ] Stress test: 100 sequential timeouts in CI shows no leaked observers (verified via leak counter or `xctrace`)

**Error contract registered with STORY-016**
- [ ] Codes: `wait_timeout`, `target_application_terminated`, `accessibility_permission_required`, `unsupported_notification`, `element_not_found`, `timeout_exceeds_maximum`
- [ ] All codes registered in `ErrorCodeRegistry` at server startup

**Tests**
- [ ] All BDD scenarios pass in CI (Cucumberish runs `story-008-axobserver-wait-for-ui-event.feature`)
- [ ] Unit test coverage ≥ 85% for `AXObserverManager` and `WaitForUIEventTool`
- [ ] Living documentation generator (`LivingDocumentationGeneratorTests`) maps every scenario to ≥ 1 unit test

**Documentation**
- [ ] `docs/stories/STORY-008-axobserver-wait-for-ui-event.md` (this file) committed
- [ ] `Tests/MCP-MacOSControlTests/Features/story-008-axobserver-wait-for-ui-event.feature` committed
- [ ] README "Tools" section updated with the new tool

---

## 9. Notes & Observations

- **Why not split into `AXObserverManager` foundation + tool layer (008a/008b)?** The manager is consumed only by STORY-008 itself. The foundation-story pattern in STORY-001 was justified by four downstream consumers (002/003/004/008). One consumer doesn't earn the ceremony.
- **Why is `AXObserverManager` an actor?** AXObserver callbacks fire on the run loop thread that owns the source. Multiplexing across N concurrent MCP calls requires serialized access to the subscription map. Swift `actor` is the right concurrency primitive; alternatives (`DispatchQueue`-guarded class) would work but cost more boilerplate.
- **Relationship to STORY-013 (MCP Resources):** STORY-013 uses `NSWorkspace` observers, NOT `AXObserver`. The two infrastructures live separately. STORY-008 borrows from STORY-013 for the app-termination side-channel only.
- **Relationship to STORY-018 (`wait_for_app_event`):** Sister story, NSWorkspace-only. Same Round 6 introduction. Does not share infrastructure with this story beyond the NSWorkspace termination observer.
