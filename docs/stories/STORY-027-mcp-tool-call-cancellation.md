# STORY-027 — MCP Tool-Call Cancellation Support

**Epic:** EPIC-7 · Production Hardening
**Priority:** 🔴 Critical
**Story Points:** 3
**Sprint Target:** Sprint 6 (Hardening)
**Dependencies:** 🔒 STORY-008 (wait tools), 🔒 STORY-009, 🔒 STORY-010 (smart_interact), 🔒 STORY-016 (structured errors), 🔒 STORY-018 (already shipped — adds cancellation paths)
**Refinement Round:** 8 — Closes the cross-cutting carry-forward from Round 6 (Q5 in STORY-008, STORY-009) and Round 7 (also flagged in STORY-010). Affects five shipped long-running tools.

---

## 1. User Story Narrative

```
Story: MCP Tool-Call Cancellation Support
In order to abort a long-running tool call before its timeout when the agent has changed its mind or the user has cancelled the upstream operation
As an AI agent (or its host application) using the MCP server
I want the server to honor MCP's standard notifications/cancelled message and propagate cancellation to all in-flight tool implementations
So that long waits and multi-layer interactions don't burn server resources after the caller has abandoned them, and so that resource hygiene (observer registrations, polling loops, layer fallbacks) is correct under cancellation
```

**Additional Context:** The MCP specification defines `notifications/cancelled` as the protocol-level mechanism for aborting an in-flight tool call. The `ToolRouter` in `Sources/MacOSControlLib/` currently doesn't consume those notifications, meaning every long-running tool — `wait_for_ui_event` (up to 300s), `wait_for_element_state` (up to 120s), `wait_for_app_event` (up to 300s), `smart_interact` (up to 4 layer attempts), `run_applescript` (with timeout) — runs to completion regardless of whether the caller still wants the answer. This is wasteful at best and resource-leak-prone at worst (an AXObserver registered for a wait the caller no longer cares about is a leaked observer). Round 6 deferred this as a cross-cutting concern with the rationale "MCP protocol-level cancellation should be the answer at the server layer, not in any single wait tool." Round 7 added smart_interact to the affected surface. Round 8 is the right time to fix it.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-7 @story-027 @protocol @cancellation
Feature: MCP Tool-Call Cancellation Support
  In order to abort in-flight tool calls cleanly
  As an AI agent or MCP host
  I want the server to honor notifications/cancelled and propagate cancellation

  Background:
    Given the MCP server is running with all Epic 5 wait tools and Epic 6 smart_interact

  # --- Protocol-level handling ---

  Scenario: ToolRouter accepts and routes notifications/cancelled
    Given a tool call is in flight with request_id "req-abc-123"
    When the client sends notifications/cancelled with requestId "req-abc-123"
    Then the ToolRouter routes the cancellation to the in-flight tool's cancellation handle
    And the server does not respond to the original tool call after cancellation
    And no error is sent back to the client (notifications/cancelled is fire-and-forget per MCP spec)

  Scenario: Cancellation for an unknown request_id is ignored silently
    Given no tool call is in flight with request_id "nonexistent"
    When the client sends notifications/cancelled with requestId "nonexistent"
    Then the server logs the unknown-request_id at info level
    And no error response is generated

  # --- Wait tool cancellation ---

  Scenario: Cancelling wait_for_ui_event unregisters its AXObserver subscription
    Given wait_for_ui_event is in flight for notification "AXWindowCreated" in "TextEdit"
    When notifications/cancelled fires for that request
    Then within 100ms the AXObserverManager unregisters the multiplexed subscription
    And if this was the last waiter on the (pid, notification) tuple, the underlying AXObserver is destroyed
    And no further callbacks fire for the cancelled request

  Scenario: Cancelling wait_for_element_state halts the polling loop within one poll cycle
    Given wait_for_element_state is in flight polling at 100ms cadence
    When notifications/cancelled fires for that request
    Then within 200ms the polling loop exits
    And no further AX tree reads are performed for the cancelled request

  Scenario: Cancelling wait_for_app_event removes its NSWorkspace observer
    Given wait_for_app_event is in flight subscribed to NSWorkspaceDidLaunchApplicationNotification
    When notifications/cancelled fires for that request
    Then within 100ms the NSWorkspaceEventBridge removes the matching observer
    And shared underlying observers are kept alive only if other waiters need them

  # --- smart_interact cancellation ---

  Scenario: Cancelling smart_interact mid-layer-attempt aborts the current layer and skips remaining layers
    Given smart_interact is in flight attempting the AppleScript layer
    When notifications/cancelled fires for that request
    Then within 200ms the current AppleScript invocation is cancelled
    And no subsequent layer (hit-test, coordinate) is attempted
    And the decision_log is preserved up to the cancellation point

  Scenario: Cancelling smart_interact between layer attempts is detected immediately
    Given smart_interact has just completed the AX semantic layer with .skipped outcome
    When notifications/cancelled fires before the AppleScript layer begins
    Then the AppleScript layer is not invoked
    And the response is suppressed (no client response sent)

  # --- run_applescript cancellation ---

  Scenario: Cancelling run_applescript terminates the osascript subprocess
    Given run_applescript is executing with a script that sleeps for 60 seconds
    When notifications/cancelled fires for that request
    Then within 500ms the osascript subprocess receives SIGTERM
    And if the process does not exit within an additional 1000ms it receives SIGKILL
    And the audit record for the cancelled invocation is written with execution_outcome "cancelled"

  # --- Resource hygiene under cancellation ---

  Scenario: Cancellation while AXObserver subscription is initializing is idempotent
    Given wait_for_ui_event has been requested but the AXObserverManager has not yet completed subscription setup
    When notifications/cancelled fires for that request
    Then the subscription setup completes followed by immediate teardown
    And no AXObserver remains registered after both operations finish
    And no race condition leaves a half-initialized observer

  Scenario: Double cancellation is idempotent
    Given wait_for_ui_event is in flight
    And notifications/cancelled has already been processed for that request
    When a second notifications/cancelled arrives for the same request_id
    Then the second notification is logged at debug level and ignored
    And no error is raised

  Scenario: Server shutdown cancels every in-flight tool call
    Given five long-running tool calls are in flight
    When the server receives SIGTERM
    Then all five are cancelled via the same cancellation pathway
    And all five complete their resource teardown within 2 seconds
    And the server exits cleanly within 3 seconds total

  Scenario Outline: Every long-running tool participates in cancellation
    Given <tool> is in flight
    When notifications/cancelled fires for that request
    Then the tool's resources are released within <budget_ms> milliseconds
    And the tool's response is suppressed

    Examples:
      | tool                     | budget_ms |
      | wait_for_ui_event        | 100       |
      | wait_for_element_state   | 200       |
      | wait_for_app_event       | 100       |
      | smart_interact           | 1000      |
      | run_applescript          | 1500      |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | ToolRouter routes cancellation; each tool responds to cancellation | ✅ |
| Alternative success path | Cancellation between layer attempts; shared observer survives partial cancellation | ✅ |
| Boundary condition | Cancellation during subscription init (race); double cancellation idempotent; outline of per-tool budgets | ✅ |
| Error / rejection path | Unknown request_id silent ignore; server shutdown cancellation path | ✅ |
| Business rule edge case | Audit record for cancelled run_applescript marked execution_outcome=cancelled | ✅ |

---

## 4. Three Amigos Open Questions

| # | Question | Resolution |
|---|---|---|
| Q1 | How does the ToolRouter track in-flight requests? | **A `[RequestId: CancellationToken]` dictionary owned by an actor.** Tokens are created at tool dispatch time and removed at response/cancellation. _[NEEDS CONFIRMATION]_ |
| Q2 | Should cancellation produce a response payload to the client? | **No — per MCP spec.** `notifications/cancelled` is fire-and-forget; the server simply doesn't send a response to the original request. The client must already be prepared for that outcome. _[NEEDS CONFIRMATION]_ |
| Q3 | What if a tool has already started writing its response when cancellation arrives? | **Race window — best-effort.** If the response is mid-flight, it may still arrive. The client must handle "response arrives after cancellation" gracefully (per MCP guidance). The server does not attempt to retract sent bytes. |
| Q4 | What about tools that are designed to be quick (e.g., `click_element`, `accessibility_tree`)? | **Cancellation supported but rarely useful.** Quick tools complete before a cancellation can practically arrive. The protocol path is exercised uniformly to keep the implementation simple; the no-op path is cheap. |
| Q5 | What's the audit-record signal for cancelled invocations? | **`execution_outcome: "cancelled"`** is a new enum value in the STORY-024 audit schema. STORY-024 will receive a Round 8 patch to add the value. _[NEEDS CONFIRMATION]_ |
| Q6 | Should there be a configurable grace period for cancellation? | **No — per-tool budgets are baked in.** A configurable grace period adds an ops dimension without obvious value; tools that need more time should be re-architected. |
| Q7 | Cancellation during the AppleScript filter's pre-flight check (before osascript spawns) | **Cancellation accepted; check abandoned.** The filter check is fast (<10ms typically) but uniform handling matters more than the edge case. |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| ToolRouter routes cancellation | When notification arrives | When | `ToolRouter.handleCancellation(requestId:)` | test_handleCancellation_invokesTokenForKnownRequestId |
| Unknown request_id ignored | Given no in-flight call | Given | `ToolRouter.handleCancellation(requestId:)` | test_handleCancellation_logsAndIgnoresUnknownRequestId |
| Wait tool teardown | Given wait in flight | Given | `WaitForUIEventTool.cancel()` | test_cancel_unregistersAXObserverWithin100ms |
| Polling tool teardown | Given polling | Given | `WaitForElementStateTool.cancel()` | test_cancel_haltsPollingLoopWithinOnePollCycle |
| App-event tool teardown | Given NSWorkspace observer | Given | `WaitForAppEventTool.cancel()` | test_cancel_removesNSWorkspaceObserverWithin100ms |
| smart_interact mid-layer | Given layer attempt in flight | Given | `InteractionRouter.cancel()` | test_cancel_abortsCurrentLayerAttempt, test_cancel_skipsRemainingLayers, test_cancel_preservesDecisionLogUpToPoint |
| run_applescript subprocess | When cancellation | When | `AppleScriptExecutor.cancel()` | test_cancel_sendsSIGTERMWithin500ms, test_cancel_escalatesToSIGKILLAfter1500ms, test_cancel_writesAuditRecordWithCancelledOutcome |
| Race: subscription init | Given mid-setup | Given | `AXObserverManager.cancel(subscriptionToken:)` | test_cancel_duringInit_completesSetupThenTearsDown_noLeak |
| Double cancellation | Given already cancelled | Given | `ToolRouter.handleCancellation(requestId:)` | test_handleCancellation_isIdempotent |
| Server shutdown | When SIGTERM | When | `MCPServer.shutdown()` | test_shutdown_cancelsAllInFlightCalls, test_shutdown_completesWithin3Seconds |
| Per-tool budget outline | Each tool | Then | (per-tool cancel tests above) | (covered above; outline integration verified in integration suite) |

---

## 6. TDD Unit Test Scaffolds

### 6.1 `ToolRouter` cancellation routing

```swift
// FILE: Tests/MCP-MacOSControlTests/Architecture/ToolRouterCancellationTests.swift
// STORY: STORY-027 — MCP Tool-Call Cancellation Support
// COMPONENT: ToolRouter (cancellation routing)

import XCTest
@testable import MacOSControlLib

final class ToolRouterCancellationTests: XCTestCase {

    var router: ToolRouter!
    var fakeLogger: FakeStructuredLogger!

    override func setUp() {
        super.setUp()
        fakeLogger = FakeStructuredLogger()
        router = ToolRouter(logger: fakeLogger)
        router.register(FakeCancellableTool(name: "fake_tool"))
    }

    func test_handleCancellation_invokesTokenForKnownRequestId() async {
        let dispatchTask = Task {
            try await router.dispatch(toolName: "fake_tool", input: [:], requestId: "req-1")
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        await router.handleCancellation(requestId: "req-1")
        do {
            _ = try await dispatchTask.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_handleCancellation_logsAndIgnoresUnknownRequestId() async {
        await router.handleCancellation(requestId: "req-nonexistent")
        XCTAssertTrue(fakeLogger.infoMessages.contains { $0.contains("req-nonexistent") })
        XCTAssertEqual(fakeLogger.errorMessages.count, 0)
    }

    func test_handleCancellation_isIdempotent() async {
        let dispatchTask = Task {
            try? await router.dispatch(toolName: "fake_tool", input: [:], requestId: "req-2")
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        await router.handleCancellation(requestId: "req-2")
        await router.handleCancellation(requestId: "req-2")  // Second cancel
        _ = await dispatchTask.value
        // No crash, no error log
        XCTAssertEqual(fakeLogger.errorMessages.count, 0)
    }
}
```

### 6.2 `WaitForUIEventTool` cancellation

```swift
// FILE: Tests/MCP-MacOSControlTests/Modules/WaitForUIEventToolCancellationTests.swift

final class WaitForUIEventToolCancellationTests: XCTestCase {

    var tool: WaitForUIEventTool!
    var fakeManager: FakeAXObserverManager!
    var fakeResolver: FakeAXElementResolver!

    override func setUp() {
        super.setUp()
        fakeManager = FakeAXObserverManager()
        fakeResolver = FakeAXElementResolver()
        tool = WaitForUIEventTool(observerManager: fakeManager, resolver: fakeResolver)
    }

    func test_cancel_unregistersAXObserverWithin100ms() async throws {
        let input = WaitForUIEventInput(notification: "AXWindowCreated",
                                        application: "TextEdit",
                                        timeoutSeconds: 30)
        let cancellationToken = CancellationToken()
        let task = Task {
            await tool.execute(input: input, cancellation: cancellationToken)
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        let startCancel = Date()
        await cancellationToken.cancel()
        _ = await task.value
        let elapsed = Date().timeIntervalSince(startCancel) * 1000
        XCTAssertLessThan(elapsed, 100, "Cancellation should release observer within 100ms")
        XCTAssertEqual(fakeManager.observerRemoveCallCount, 1)
    }
}
```

### 6.3 `InteractionRouter` cancellation between layers

```swift
// FILE: Tests/MCP-MacOSControlTests/Router/InteractionRouterCancellationTests.swift

final class InteractionRouterCancellationTests: XCTestCase {

    func test_cancel_skipsRemainingLayers() async throws {
        let layers = [
            FakeInteractionLayer(name: "ax_semantic", outcome: .skipped(reason: "no AXAction")),
            FakeInteractionLayer(name: "applescript", outcome: .skipped(reason: "no AS dict"),
                                 simulatedDelayMs: 500),
            FakeInteractionLayer(name: "ax_hit_test", outcome: .succeeded(method: "ax_hit_test", confidence: 0.7)),
            FakeInteractionLayer(name: "coordinate_fallback", outcome: .succeeded(method: "coordinate_fallback", confidence: 0.5)),
        ]
        let router = InteractionRouter(layers: layers, registry: FakeAppCapabilityRegistry())
        let token = CancellationToken()
        let task = Task {
            await router.route(input: testInput(), cancellation: token)
        }
        try await Task.sleep(nanoseconds: 100_000_000) // partway through AppleScript layer
        await token.cancel()
        let result = await task.value
        // Hit-test and coordinate_fallback should NOT have been invoked
        XCTAssertEqual(layers[2].callCount, 0)
        XCTAssertEqual(layers[3].callCount, 0)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "cancelled")
    }

    func test_cancel_preservesDecisionLogUpToPoint() async throws {
        let layers = [
            FakeInteractionLayer(name: "ax_semantic", outcome: .skipped(reason: "no AXAction")),
            FakeInteractionLayer(name: "applescript", outcome: .skipped(reason: "no AS dict"),
                                 simulatedDelayMs: 500),
        ]
        let router = InteractionRouter(layers: layers, registry: FakeAppCapabilityRegistry())
        let token = CancellationToken()
        let task = Task { await router.route(input: testInput(), cancellation: token) }
        try await Task.sleep(nanoseconds: 100_000_000)
        await token.cancel()
        let result = await task.value
        // decision_log should include ax_semantic skipped, applescript attempted-then-cancelled
        XCTAssertEqual(result.decisionLog.count, 2)
        XCTAssertEqual(result.decisionLog[0].layer, "ax_semantic")
        XCTAssertEqual(result.decisionLog[1].outcome, .cancelled)
    }
}
```

### 6.4 `AppleScriptExecutor` subprocess termination

```swift
// FILE: Tests/MCP-MacOSControlTests/AppleScript/AppleScriptExecutorCancellationTests.swift

final class AppleScriptExecutorCancellationTests: XCTestCase {

    func test_cancel_sendsSIGTERMWithin500ms() async throws {
        let executor = AppleScriptExecutor()
        let token = CancellationToken()
        let task = Task {
            // Script sleeps for 60s; cancellation should kill the subprocess long before
            try await executor.execute(source: "delay 60", cancellation: token)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let start = Date()
        await token.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            let elapsed = Date().timeIntervalSince(start) * 1000
            XCTAssertLessThan(elapsed, 1500, "Subprocess should terminate within SIGTERM + SIGKILL budget")
        }
    }

    func test_cancel_writesAuditRecordWithCancelledOutcome() async throws {
        let fakeAudit = FakeAuditRecorder()
        let executor = AppleScriptExecutor(audit: fakeAudit)
        let token = CancellationToken()
        let task = Task { try? await executor.execute(source: "delay 30", cancellation: token) }
        try await Task.sleep(nanoseconds: 100_000_000)
        await token.cancel()
        _ = await task.value
        XCTAssertEqual(fakeAudit.writtenRecords.last?.execution_outcome, "cancelled")
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Source | Notes |
|---|---|---|---|
| Swift structured concurrency `Task` and `Task.cancel()` | Standard library | No double | Foundation for cancellation propagation |
| `CancellationToken` value type | **New** | No double — pure value | Wraps a `Task` for cooperative cancellation |
| `ToolRouter` (existing) | Real (extended) | Existing fakes | Adds `handleCancellation(requestId:)` API |
| `AXObserverManager` (STORY-008) | Real | `FakeAXObserverManager` (mocks already exist) | Adds explicit `cancel(subscriptionToken:)` API |
| `NSWorkspaceEventBridge` (STORY-018) | Real | `FakeNSWorkspaceEventManaging` (exists) | Adds explicit `cancel(observerToken:)` API |
| `AppleScriptExecutor` (STORY-006) | Real | `AppleScriptExecutorSpy` (exists) | Adds subprocess-termination path |
| `AuditRecorder` (STORY-024 extended) | Real | `AuditRecorderSpy` (exists) | New `execution_outcome: "cancelled"` enum value |
| `ErrorCodeRegistry` (STORY-016) | Real | No double | Registers `cancelled` error code |

---

## 8. Definition of Done

**Protocol-level**
- [ ] `ToolRouter` consumes `notifications/cancelled` from the MCP transport layer
- [ ] `[RequestId: CancellationToken]` map maintained by a router-owned actor
- [ ] Unknown request_id cancellations logged at info level, not as errors

**Cancellation token propagation**
- [ ] `CancellationToken` value type added to `Sources/MacOSControlLib/`
- [ ] Every long-running tool's `execute(input:)` accepts a `cancellation: CancellationToken`
- [ ] Layer adapters in `InteractionRouter` accept and check cancellation between attempts

**Per-tool cancellation paths**
- [ ] `WaitForUIEventTool` — observer unregistration within 100ms
- [ ] `WaitForElementStateTool` — polling loop exit within one cycle (≤200ms)
- [ ] `WaitForAppEventTool` — NSWorkspace observer removal within 100ms
- [ ] `SmartInteractTool` — current-layer abort + remaining-layer skip; decision_log preserved
- [ ] `RunAppleScriptTool` — SIGTERM within 500ms, SIGKILL escalation within +1000ms

**Resource hygiene**
- [ ] AXObserver subscriptions cancelled mid-init complete then tear down cleanly
- [ ] Shared NSWorkspace observers survive partial cancellation (only the cancelled waiter is removed)
- [ ] No leaked subprocesses, observers, or tasks after cancellation under stress (verified by STORY-031)

**Audit integration**
- [ ] `AuditRecorder` schema extended with `execution_outcome: "cancelled"` (STORY-024 schema patch)
- [ ] Cancelled `run_applescript` invocations produce audit records with the new outcome
- [ ] STORY-024 hash chain remains intact across cancelled invocations

**Error contract**
- [ ] `cancelled` error code registered in `ErrorCodeRegistry`
- [ ] When a tool's response IS sent (race window), the response uses the structured error shape with `error_code: "cancelled"`

**Tests**
- [ ] All BDD scenarios pass in CI
- [ ] Unit coverage ≥ 85% on the new `CancellationToken` plumbing
- [ ] Integration test in `Tests/MCP-MacOSControlIntegrationTests/Workflows/CancellationWorkflowTests.swift` exercises end-to-end cancellation across each long-running tool
- [ ] Stress test: 1000 dispatch-then-cancel cycles show no leaked observers, subprocesses, or tasks

**Documentation**
- [ ] `docs/SECURITY.md` updated: cancellation mentioned as resource-hygiene measure
- [ ] `docs/stories/STORY-027-mcp-tool-call-cancellation.md` (this file) committed
- [ ] `Tests/MCP-MacOSControlTests/Features/story-027-mcp-tool-call-cancellation.feature` committed
- [ ] README "Tools" section notes which tools honor cancellation
- [ ] MCP Prompt `interaction_hierarchy` updated to recommend cancellation when an agent abandons a workflow

---

## 9. Notes & Observations

- **Why now and not earlier?** Each prior round had a more user-visible deliverable (new tools, new capabilities). Cancellation is invisible plumbing that pays off across the surface. Rounds 6 and 7 both deferred it explicitly with the note "MCP protocol-level cancellation should be the answer at the server layer, not in any single wait tool." Round 8 (hardening) is the right scope: five shipped consumers, one piece of foundation.
- **Why is the per-tool budget tighter for wait tools than for smart_interact?** Wait tools have a single resource (one observer or one polling task) to release. smart_interact may be partway through invoking a sub-tool (AppleScript subprocess, AX action call) whose own cleanup takes time. Budgets are proportional to the longest reasonable resource-release path.
- **Why doesn't the server respond to cancelled requests?** MCP specification says `notifications/cancelled` is fire-and-forget. The client has already moved on; a response would be unexpected noise. The race window (response sent before cancellation processed) is documented as client-must-handle.
- **Why is `CancellationToken` a custom type rather than just `Task.isCancelled`?** Swift `Task.isCancelled` is the right primitive at the call-site, but the cancellation needs to be triggerable from outside the dispatched task (the `ToolRouter` doesn't own the task; it owns the request_id mapping). `CancellationToken` is a thin wrapper that exposes both interfaces.
- **Relationship to STORY-031 (leak stress test):** Cancellation paths are a major source of resource leaks if implemented incorrectly. STORY-031's stress test specifically exercises 100 sequential dispatch-then-cancel cycles to verify no leaks. The two stories pay off together.
- **Relationship to STORY-024 (audit log):** The `execution_outcome: "cancelled"` enum value is a small schema addition to STORY-024's audit record. Ordering: STORY-024 lands first; STORY-027 patches the schema to add the new value.
