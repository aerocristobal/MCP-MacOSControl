// STORY-012 — End-to-End Integration Validation Suite
// COMPONENT: Base class enforcing opt-in, permission check, hard timeout.
//
// NOTE on the story's §6.1 scaffold: it put the opt-in guard in
// `override class func setUp()` and called `XCTSkip` there. `XCTSkip` only takes
// effect when thrown from an instance `setUpWithError()` / a test method — a
// class-level `setUp` cannot skip, and `XCTFail` there would turn a
// permission-less or opt-out runner *red*. We therefore guard in
// `setUpWithError()` and *skip* (never fail) when the environment is absent, so
// a plain `swift test` on PRs — which builds this target but must stay green —
// reports every integration test as skipped rather than failed.

import XCTest
import ApplicationServices
import CoreServices
@testable import MacOSControlLib

class IntegrationTestCase: XCTestCase {

    /// Opt-in flag. The whole suite no-ops unless this is exactly "true".
    static let integrationFlag = "CI_MACOS_INTEGRATION"

    /// Set once we know the suite is allowed to run — subclasses can branch on
    /// it for extra environment probing.
    private(set) var integrationEnabled = false

    override func setUpWithError() throws {
        try super.setUpWithError()

        guard ProcessInfo.processInfo.environment[Self.integrationFlag] == "true" else {
            throw XCTSkip("""
            Skipped: integration suite requires \(Self.integrationFlag)=true. \
            Run: \(Self.integrationFlag)=true swift test \
            --filter MCP-MacOSControlIntegrationTests
            """)
        }

        guard AXIsProcessTrusted() else {
            throw XCTSkip("""
            Skipped: the test runner lacks Accessibility permission. Grant it in \
            System Settings ▸ Privacy & Security ▸ Accessibility for the process \
            running `swift test` (see docs/INTEGRATION-CI-SETUP.md).
            """)
        }

        integrationEnabled = true

        // Force the lazily-bootstrapped error-code registry before any tool call
        // so MCPErrorResponseBuilder's DEBUG `assertRegistered` precondition
        // never trips inside a scenario.
        _ = ErrorCodeRegistry.shared.allRegistrations().count

        // §6 DoD: per-scenario hard cap of 60 seconds. A hung wait or runaway
        // loop must fail the scenario rather than block the 15-minute suite.
        executionTimeAllowance = 60
    }

    // MARK: - Hard wall-clock scenario guard

    struct ScenarioTimeout: Error {}

    /// Runs `body` against a real wall-clock deadline. `executionTimeAllowance`
    /// does not preempt a blocked `await` (e.g. a tool call stuck behind an
    /// un-granted Automation/Accessibility consent dialog), which is exactly
    /// the integration flakiness STORY-012 calls out. This races the body
    /// against a timer so a blocked scenario *ends* instead of stalling the
    /// 15-minute suite.
    ///
    /// On a provisioned runner a timeout is a real failure (hang or
    /// regression). For unprovisioned local "run what's possible" runs, set
    /// `MCP_INTEGRATION_SOFT_TIMEOUT=1` to downgrade the timeout to a
    /// documented skip rather than a red failure.
    func runScenario(
        seconds: Double = 45,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: @escaping () async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ScenarioTimeout()
            }
            do {
                try await group.next()
                group.cancelAll()
            } catch is ScenarioTimeout {
                group.cancelAll()
                let msg = """
                Scenario exceeded \(Int(seconds))s — a tool call is blocked \
                (commonly an un-granted Automation/Accessibility consent dialog \
                on this runner; see docs/INTEGRATION-CI-SETUP.md) or a \
                regression introduced a hang.
                """
                if ProcessInfo.processInfo.environment["MCP_INTEGRATION_SOFT_TIMEOUT"] == "1" {
                    throw XCTSkip(msg)
                }
                XCTFail(msg, file: file, line: line)
            }
        }
    }

    // MARK: - Automation (Apple Events) pre-flight

    /// Non-blocking probe of whether this process may send Apple Events to
    /// `bundleID`. CRITICAL: an un-granted Automation consent dialog blocks
    /// `osascript` indefinitely and starves the Swift-concurrency executor —
    /// `runScenario`'s timer (and even the tool's own timeout) then never get
    /// to run. The only safe move is to *not issue the blocking call*: probe
    /// here with `askUserIfNeeded=false` (no dialog) and skip with a documented
    /// reason when consent has not been pre-granted. On a provisioned runner
    /// (docs/INTEGRATION-CI-SETUP.md) the probe returns noErr and the scenario
    /// runs for real.
    func skipUnlessAutomationAuthorized(
        _ bundleID: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        var target = AEAddressDesc()
        let data = Array(bundleID.utf8)
        let create = AECreateDesc(
            DescType(typeApplicationBundleID), data, data.count, &target)
        guard create == noErr else {
            throw XCTSkip("Could not build an AEAddressDesc for \(bundleID) (status \(create)).")
        }
        defer { AEDisposeDesc(&target) }

        let status = AEDeterminePermissionToAutomateTarget(
            &target, AEEventClass(typeWildCard), AEEventID(typeWildCard), false)

        if status != noErr {
            throw XCTSkip("""
            Skipped: this process is not pre-authorized to send Apple Events to \
            \(bundleID) (AEDeterminePermissionToAutomateTarget status \(status)). \
            Issuing run_applescript here would block on a consent dialog. Grant \
            Automation for the test runner (docs/INTEGRATION-CI-SETUP.md) or run \
            on a provisioned runner. The AppleScript layer itself is proven by \
            STORY-006/007 unit tests.
            """)
        }
    }

    // MARK: - Environment probes used by tagged scenarios

    /// iPhone Mirroring requires macOS 15 + a paired iPhone + a calibrated
    /// session — rare on CI. Tagged scenarios call this to skip with a
    /// structured reason on incompatible runners (`requires_iphone_mirroring`).
    func skipUnlessIPhoneMirroring(_ harness: IntegrationHarness) async throws {
        let status = try await harness.call("iphone_status", [:])
        let running = (status.json["running"] as? Bool)
            ?? (status.json["connected"] as? Bool)
            ?? false
        if status.isError || !running {
            throw XCTSkip("""
            Skipped [requires_iphone_mirroring]: iPhone Mirroring is not \
            connected/calibrated on this runner. reason=\
            \(status.errorCode ?? "not_running").
            """)
        }
    }
}
