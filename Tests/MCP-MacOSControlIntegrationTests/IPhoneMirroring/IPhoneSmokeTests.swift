// STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: iPhone Mirroring smoke test — coordinate path unaffected by Epic 6
// Re-validates: existing IPhoneMirroringModule (21 tools)
// Tag: requires_iphone_mirroring
//
// macOS 15 + a paired, calibrated iPhone is rare on CI. `skipUnlessIPhoneMirroring`
// skips with a structured reason on incompatible runners; where present, this
// proves the normalized-coordinate tap path still works and the iPhone tool
// responses did not regress in shape under Epic 6.

import XCTest
import MCP
@testable import MacOSControlLib

final class IPhoneSmokeTests: IntegrationTestCase {

    private let harness = IntegrationHarness()

    func test_iphoneScreenshot_thenTap_changesScreen() async throws {
        try await skipUnlessIPhoneMirroring(harness)
        let harness = self.harness
        try await runScenario(seconds: 30) {
            let before = try await harness.require("iphone_screenshot", [:])
            XCTAssertFalse(before.rawText.isEmpty, "iphone_screenshot returned empty")

            let tap = try await harness.call("iphone_tap", [
                "x": .double(0.5), "y": .double(0.5)
            ])
            XCTAssertFalse(tap.isError, "iphone_tap at (0.5,0.5) failed: \(tap.rawText)")
            // Gherkin: "no schema_version regression occurs in the iPhone tool
            // responses". The shipped iPhone tools never carried schema_version
            // — guard that Epic 6 did not retro-introduce it, and that the
            // semantic-router keys did not leak in either.
            for leaked in ["interaction_method", "decision_log", "schema_version"] {
                XCTAssertFalse(tap.rawText.contains(leaked),
                    "Epic 6 / schema key '\(leaked)' leaked into iphone_tap response")
                XCTAssertFalse(before.rawText.contains(leaked),
                    "Epic 6 / schema key '\(leaked)' leaked into iphone_screenshot response")
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let after = try await harness.require("iphone_screenshot", [:])
            XCTAssertNotEqual(before.rawText, after.rawText,
                "iPhone screen did not change after the tap (screenshot diff)")
        }
    }
}
