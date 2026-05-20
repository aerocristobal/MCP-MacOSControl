# STORY-012 — End-to-End Integration Validation Suite

**Epic:** EPIC-6 · Agent Interaction Hierarchy
**Priority:** 🟡 High
**Story Points:** 5
**Sprint Target:** Sprint 5
**Dependencies:** 🔒 All prior shipping stories (currently 001–009, 011, 013–019). Specifically requires STORY-010 (smart_interact router) and STORY-018 (wait_for_app_event) for new Round 7 scenarios; STORY-020 (app compatibility catalog) feeds the regression matrix.
**Refinement Round:** 7 — Epic 6 expansion. Scenarios 3 → 7; added NSWorkspace launch flow (STORY-018), iPhone Mirroring smoke test, failure-recovery via smart_interact, mid-test permission revocation, and structured-error contract regression check.

---

## 1. User Story Narrative

```
Story: End-to-End Integration Validation Suite
In order to catch regressions across every interaction layer before release
As a developer maintaining MCP-MacOSControl
I want a suite of integration tests that exercise full agent workflows against real macOS applications
So that schema changes, layer additions, and security tightening do not silently break the agent contract
```

**Additional Context:** This is the final story of Epic 6 — the proving ground for the four-layer hierarchy and every downstream consumer. Unit tests verify each component in isolation; this suite verifies the whole thing actually works when AX, AppleScript, hit-test, coordinate, NSWorkspace, iPhone Mirroring, MCP Resources, MCP Prompts, and structured-error contracts all run together against real applications. The suite is CI-gated behind an explicit opt-in flag because it requires accessibility permissions, a logged-in macOS GUI session, and a set of pre-installed apps — incompatible with the standard ephemeral runner. Round 7 expands it to validate the Round 5/6 additions: NSWorkspace lifecycle waits, the structured-error contract, iPhone Mirroring as a first-class capability, and the smart_interact router as the recommended entry point.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-6 @story-012 @integration
Feature: End-to-End Integration Validation Suite
  In order to catch regressions across all interaction layers
  As a developer
  I want integration tests covering full agent workflows against real macOS apps

  Background:
    Given the full MCP server is running
    And macOS system accessibility is enabled for the test runner
    And the CI environment variable CI_MACOS_INTEGRATION = true
    And TextEdit, Finder, Safari, Calculator, and Script Editor are available

  # --- Round 4 scenarios (preserved, refined to current tool set) ---

  Scenario: Complete agent workflow — open, type, save a document
    Given no TextEdit documents are open
    When the AI agent executes the following workflow:
      | Step | Tool                    | Action                                       |
      | 1    | run_applescript         | Open a new TextEdit document                 |
      | 2    | wait_for_ui_event       | Wait for AXWindowCreated in TextEdit         |
      | 3    | click_element           | Click the text area                          |
      | 4    | type_text               | Type "Integration test document"             |
      | 5    | click_menu_item         | Click File → Save                            |
      | 6    | wait_for_ui_event       | Wait for Save sheet to appear                |
      | 7    | type_text               | Type filename "integration-test"             |
      | 8    | perform_ax_action       | AXPress the Save button                      |
    Then a file named "integration-test.rtf" exists on disk under the test temp directory
    And each tool response includes the correct interaction_method
    And the elapsed wall-clock for the workflow is under 15 seconds

  Scenario: Validate interaction method selection across app types
    Given TextEdit (AX-supported) and a known AX-degraded legacy app are both running
    When the AI agent calls smart_interact with intent "click" against a button in each application
    Then the TextEdit call returns interaction_method "ax_semantic"
    And the legacy app call returns interaction_method "applescript", "ax_hit_test", or "coordinate_fallback"
    And both responses include a non-empty decision_log

  Scenario: Confirm no regressions in existing coordinate-based tools
    Given any open application window
    When the AI agent calls the existing click_screen tool with valid coordinates
    Then the click is delivered correctly
    And existing tool response formats remain backward-compatible with schema_version 2 consumers

  # --- Round 7 additions ---

  Scenario: NSWorkspace launch flow — open Calculator from a not-running state
    Given Calculator is not currently running
    When the AI agent executes the following workflow:
      | Step | Tool                | Action                                                                   |
      | 1    | wait_for_app_event  | Subscribe to event=launched bundle_id="com.apple.calculator", timeout=10 |
      | 2    | run_applescript     | tell application "Calculator" to activate                                |
      | 3    | wait_for_ui_event   | Wait for AXWindowCreated in Calculator                                   |
      | 4    | smart_interact      | intent=click target_description="5" application="com.apple.calculator"   |
    Then step 1 resolves with bundle_identifier "com.apple.calculator"
    And step 3 returns within 5 seconds of step 2
    And step 4's interaction_method is "ax_semantic"
    And the Calculator display reads "5" after the workflow completes

  Scenario: Failure-recovery — smart_interact falls back and reports decision_log
    Given an application whose AX tree is intentionally degraded (synthesized via a test harness app)
    When the AI agent calls smart_interact with intent "click" target_description "Action" against that app
    Then the response's interaction_method is "applescript" or "coordinate_fallback"
    And the decision_log shows ax_semantic was attempted and either skipped or failed
    And the decision_log records the elapsed milliseconds for each attempted layer
    And the total wall-clock for the call is under 3 seconds

  Scenario: iPhone Mirroring smoke test — coordinate-based path is unaffected by Epic 6 changes
    Given iPhone Mirroring is connected and calibrated on the test machine
    When the AI agent calls iphone_screenshot then iphone_tap at normalized coordinates (0.5, 0.5)
    Then the iphone_tap response indicates success
    And the iPhone screen content has measurably changed within 2 seconds (via a follow-up iphone_screenshot diff)
    And no schema_version regression occurs in the iPhone tool responses

  Scenario: Mid-workflow permission revocation surfaces a structured error
    Given a workflow is in progress and has called wait_for_ui_event
    When macOS Accessibility permission is revoked from the MCP process mid-call
    Then the in-flight tool returns a structured error with error_code "accessibility_permission_required"
    And the error_code matches the code shipped under STORY-016
    And no subsequent tool call crashes the server — every following call returns the same structured error
    And the server logs the revocation event with a structured log entry

  Scenario: Structured-error contract honored across every error path
    Given the integration suite runs the dedicated error-injection variant
    When each registered error_code from STORY-016 is forced (one per sub-scenario)
    Then every error response matches the structured shape { error_code, message, details, isError: true }
    And the error_code matches a code registered in ErrorCodeRegistry
    And no error is returned as a bare string or with isError: false
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | Open-type-save workflow | ✅ |
| Alternative success path | NSWorkspace launch flow; smart_interact across app types; iPhone Mirroring smoke | ✅ |
| Boundary condition | Coordinate tool backward compatibility | ✅ |
| Error / rejection path | Failure recovery via smart_interact; mid-workflow permission revocation | ✅ |
| Business rule edge case | Structured-error contract enforced across every code | ✅ |

---

## 4. Three Amigos Open Questions (Round 7)

| # | Question | Resolution |
|---|---|---|
| Q1 | How are the test apps installed on CI runners? | **GitHub Actions macOS runners ship TextEdit, Finder, Safari, Calculator, Script Editor by default.** Third-party (legacy AX-degraded) test app is a custom test-harness Swift target built and run only by the integration suite, not external. _[NEEDS CONFIRMATION]_ |
| Q2 | How is accessibility permission pre-granted for CI? | **CI runner provisioning step uses `tccutil reset Accessibility com.apple.dt.xctest.tool` then a launchd-level grant via a developer-signed helper.** This is the only viable path on macOS 13+; documented in `docs/INTEGRATION-CI-SETUP.md`. _[NEEDS CONFIRMATION]_ |
| Q3 | Do integration tests run on every PR or only on merge to main? | **On merge to main + scheduled nightly + on-demand via workflow_dispatch.** Per-PR is too expensive (~3 min for full suite) and too flaky on shared runners. Unit tests catch ≥ 95% of regressions; integration suite is the safety net. _[NEEDS CONFIRMATION]_ |
| Q4 | What's the test-harness app for AX-degraded scenarios? | **A small SwiftUI app with `accessibilityHidden(true)` on key controls,** built as a sub-target. Reproducible, version-controlled, doesn't depend on a moving third-party Electron app. |
| Q5 | iPhone Mirroring integration — required or skipped on CI? | **Required on a designated runner only,** marked with the `requires_iphone_mirroring` tag. The macOS 15 + paired iPhone setup is rare on CI runners; skip with structured reason on runners that don't have it. _[NEEDS CONFIRMATION]_ |
| Q6 | How long can the suite run before timeout? | **15 minutes hard cap.** Individual scenario cap: 60 seconds. Anything taking longer is a signal of a hung wait or a runaway loop and must fail rather than block CI. |
| Q7 | What about scenarios that exercise STORY-017 (MCP Prompts) and STORY-013 (MCP Resources)? | **Cover in the existing unit test suites, not here.** Integration suite focuses on workflows; Prompts/Resources are static-data primitives that don't need integration coverage beyond "they exist and respond." A single smoke test confirming both endpoints respond is acceptable. _[NEEDS CONFIRMATION]_ |

---

## 5. TDD Implementation Map

> Integration scenarios have a different test-mapping shape than unit-test stories: each scenario is itself an end-to-end test, and the "components under test" are end-to-end systems. The map below records which prior story's invariants each scenario re-validates.

| BDD Scenario | Re-validates invariants from | Integration Test File |
|---|---|---|
| Open-type-save workflow | STORY-002, STORY-006, STORY-007, STORY-008 | `IntegrationTests/Workflows/OpenTypeSaveWorkflowTests.swift` |
| Interaction method selection | STORY-010, STORY-019 | `IntegrationTests/Workflows/SmartInteractRoutingTests.swift` |
| Coordinate tool backward compatibility | Existing `MouseModule`, `KeyboardModule` | `IntegrationTests/Regression/CoordinateToolBackCompatTests.swift` |
| NSWorkspace launch flow | STORY-018, STORY-008, STORY-010 | `IntegrationTests/Workflows/NSWorkspaceLaunchFlowTests.swift` |
| Failure recovery via smart_interact | STORY-010, STORY-019 | `IntegrationTests/Workflows/SmartInteractFallbackTests.swift` |
| iPhone Mirroring smoke | Existing `IPhoneMirroringModule` (21 tools) | `IntegrationTests/IPhoneMirroring/IPhoneSmokeTests.swift` |
| Permission revocation mid-workflow | STORY-016, STORY-008 | `IntegrationTests/Security/PermissionRevocationTests.swift` |
| Structured-error contract enforcement | STORY-016 — every registered code | `IntegrationTests/Contract/ErrorCodeContractTests.swift` |

---

## 6. TDD Unit Test Scaffolds (Integration variants)

### 6.1 Integration test runner conventions

```swift
// FILE: Tests/MCP-MacOSControlIntegrationTests/IntegrationTestCase.swift
// STORY: STORY-012 — End-to-End Integration Validation Suite
// COMPONENT: Base class enforcing opt-in, permissions check, hard-timeout

import XCTest

/// Base class for all macOS integration tests. Skips unless CI_MACOS_INTEGRATION=true
/// and accessibility permissions are present. Enforces per-scenario timeout.
class IntegrationTestCase: XCTestCase {

    override class func setUp() {
        super.setUp()
        guard ProcessInfo.processInfo.environment["CI_MACOS_INTEGRATION"] == "true" else {
            XCTSkip("Integration tests require CI_MACOS_INTEGRATION=true environment variable.")
            return
        }
        guard AXIsProcessTrusted() else {
            XCTFail("Integration tests require accessibility permission for the test runner.")
            return
        }
    }

    /// All integration scenarios must complete within 60 seconds.
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 60
    }
}
```

### 6.2 Sample integration scenario

```swift
// FILE: Tests/MCP-MacOSControlIntegrationTests/Workflows/NSWorkspaceLaunchFlowTests.swift
// STORY: STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: NSWorkspace launch flow — open Calculator from a not-running state

import XCTest
@testable import MacOSControlLib

final class NSWorkspaceLaunchFlowTests: IntegrationTestCase {

    var server: MCPServer!

    override func setUp() {
        super.setUp()
        server = MCPServer.makeForIntegrationTests()
        terminateCalculatorIfRunning()
    }

    override func tearDown() {
        terminateCalculatorIfRunning()
        super.tearDown()
    }

    func test_workflow_launchesCalculatorViaNSWorkspaceAndClicksButton() async throws {
        // Step 1 — subscribe to launch event
        let launchTask = Task {
            try await server.callTool("wait_for_app_event", input: [
                "event": "launched",
                "bundle_identifier": "com.apple.calculator",
                "timeout_seconds": 10
            ])
        }

        // Step 2 — activate Calculator
        _ = try await server.callTool("run_applescript", input: [
            "script": "tell application \"Calculator\" to activate"
        ])

        // Verify step 1 resolved
        let launchResult = try await launchTask.value
        XCTAssertEqual(launchResult.content["bundle_identifier"] as? String, "com.apple.calculator")

        // Step 3 — wait for window
        let windowResult = try await server.callTool("wait_for_ui_event", input: [
            "notification": "AXWindowCreated",
            "application": "Calculator",
            "timeout_seconds": 5
        ])
        XCTAssertFalse(windowResult.isError)

        // Step 4 — smart_interact click
        let clickResult = try await server.callTool("smart_interact", input: [
            "intent": "click",
            "target_description": "5",
            "application": "com.apple.calculator"
        ])
        XCTAssertEqual(clickResult.content["interaction_method"] as? String, "ax_semantic")

        // Verify side effect — Calculator display reads "5"
        let snapshot = try await server.callTool("accessibility_tree", input: [
            "application": "Calculator", "max_depth": 6
        ])
        let displayValue = extractCalculatorDisplay(from: snapshot)
        XCTAssertEqual(displayValue, "5")
    }
}
```

### 6.3 Error-code contract test

```swift
// FILE: Tests/MCP-MacOSControlIntegrationTests/Contract/ErrorCodeContractTests.swift
// STORY: STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: Structured-error contract honored across every error path

import XCTest
@testable import MacOSControlLib

final class ErrorCodeContractTests: IntegrationTestCase {

    var server: MCPServer!

    override func setUp() {
        super.setUp()
        server = MCPServer.makeForIntegrationTests()
    }

    func test_everyRegisteredErrorCode_returnsStructuredErrorShape() async throws {
        for errorCode in ErrorCodeRegistry.shared.allRegisteredCodes {
            // Each code has an associated "trigger recipe" in a manifest file
            guard let recipe = ErrorTriggerManifest.recipe(for: errorCode) else {
                XCTFail("No trigger recipe for error_code: \(errorCode)")
                continue
            }
            let response = try await server.callTool(recipe.toolName, input: recipe.input)
            XCTAssertTrue(response.isError, "\(errorCode) did not return isError=true")
            XCTAssertEqual(response.errorCode, errorCode)
            XCTAssertNotNil(response.message)
            XCTAssertNotNil(response.details)
        }
    }
}
```

---

## 7. Dependencies & Test Doubles

> Integration tests use REAL components by definition — no mocks. The "doubles" used here are isolation aids only.

| Dependency | Type | Notes |
|---|---|---|
| Real macOS GUI session | Required | CI runner must have an active loginwindow session |
| Real TextEdit, Finder, Safari, Calculator, Script Editor | Required | Pre-installed on macOS GitHub Actions runners |
| AX-degraded test harness app | **New** | A small SwiftUI target with `accessibilityHidden(true)` on controls; built by the integration suite, not external |
| `ErrorTriggerManifest` | **New** test fixture | One entry per `ErrorCodeRegistry` code with a recipe (tool name + input) that forces that code |
| Real `MCPServer` | Required | Started for each test class; torn down on teardown |
| `tccutil` reset helper | CI provisioning | Resets and re-grants accessibility permission cleanly between runs |

---

## 8. Definition of Done

**Test infrastructure**
- [ ] `Tests/MCP-MacOSControlIntegrationTests/` Swift test target added, separate from existing `Tests/MCP-MacOSControlTests/`
- [ ] `IntegrationTestCase` base class enforces `CI_MACOS_INTEGRATION=true` opt-in
- [ ] Per-scenario timeout: 60 seconds. Suite timeout: 15 minutes.
- [ ] `.github/workflows/ci-integration.yml` — runs on main + nightly + on-demand
- [ ] `docs/INTEGRATION-CI-SETUP.md` — documents CI runner provisioning (accessibility permission grant, app installation)

**Scenario coverage**
- [ ] All seven BDD scenarios above implemented and passing on macOS 13+ (Ventura, Sonoma, Sequoia)
- [ ] AX-degraded test harness app built as a sub-target
- [ ] iPhone Mirroring scenario tagged `requires_iphone_mirroring`; skipped with structured reason on incompatible runners

**Regression catalog integration (STORY-020)**
- [ ] Each integration scenario records its observed `interaction_method` and writes it to a JSON artifact consumed by STORY-020's compatibility catalog generator
- [ ] If observed `interaction_method` differs from registry expectation, the scenario fails with a clear diff

**Structured-error contract enforcement**
- [ ] `ErrorTriggerManifest` covers 100% of `ErrorCodeRegistry`-registered codes
- [ ] `ErrorCodeContractTests` fails fast if a code is registered without a trigger recipe

**Backward compatibility**
- [ ] All pre-existing coordinate-based tool response formats validated against shipped schema_version
- [ ] No iPhone Mirroring response shape regressions

**Documentation**
- [ ] `docs/stories/STORY-012-end-to-end-integration-validation.md` (this file) committed
- [ ] `Tests/MCP-MacOSControlIntegrationTests/Features/story-012-end-to-end-integration-validation.feature` committed
- [ ] README updated: section on the integration suite, how to run locally
- [ ] `CONTRIBUTING.md` (if it exists, else create) explains the AX permission setup contributors need

---

## 9. Notes & Observations

- **Why a separate test target?** Integration tests have different requirements (permissions, real apps, longer timeouts, opt-in) and a different failure-investigation flow than unit tests. Mixing them dilutes both. Swift Package Manager supports multiple test targets cleanly.
- **Why doesn't this story have story points proportional to its scenario count?** Because each scenario is mostly "stitch existing shipped tools in a particular order." The new code is: the test target scaffolding, the base class, the harness app, the trigger manifest, and the CI workflow. The scenarios themselves are mostly tool composition.
- **Why is the AX-degraded harness app preferred over a real Electron app?** Reproducibility. Slack 4.x and 5.x have different AX trees. Tests against a moving third-party target are flaky and inscrutable when they fail. A first-party harness is version-controlled and intentional.
- **Why CI on merge + nightly rather than per-PR?** Cost and flakiness. macOS GitHub Actions runners are 10× more expensive than Linux. Integration tests on shared runners flake due to permission timing. The combination is a constant CI noise source per-PR; on merge + nightly catches regressions within ~24 hours which is fast enough for a v0/v1 product.
- **Relationship to STORY-020 (App Compatibility Catalog):** STORY-012 produces empirical observations (this scenario got `applescript`, this one got `ax_semantic`). STORY-020 aggregates those observations into a maintained document. The two stories are intentionally separate so the catalog grows independently of the test suite's pace.
- **Why no integration scenario for STORY-013 (Resources) or STORY-017 (Prompts)?** They're static-data primitives that respond to `list` / `read` / `get`. Unit tests already prove they expose the right data. Integration coverage would add expensive runs without finding new bugs. A single smoke test confirming both endpoints are reachable is folded into the test setup, not a dedicated scenario.
