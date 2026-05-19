// STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: Confirm no regressions in existing coordinate-based tools
// Re-validates: existing MouseModule, KeyboardModule
//
// Epic 6 added the four-layer hierarchy + structured JSON envelopes. The
// pre-existing coordinate primitives intentionally still return their original
// *plain-text* confirmation strings (e.g. "Clicked at (x, y) with left
// button", "Screen size: WxH") — that bare-string shape *is* the shipped
// backward-compatibility contract for schema_version-2 consumers. This guards
// that Epic 6 did not silently JSON-ify them or leak interaction_method /
// schema_version / decision_log into them.

import XCTest
import MCP
@testable import MacOSControlLib

final class CoordinateToolBackCompatTests: IntegrationTestCase {

    private let harness = IntegrationHarness()

    func test_coordinateTools_keepLegacyPlainTextResponses() async throws {
        // get_screen_size → "Screen size: WxH" (plain text, unchanged).
        let size = try await harness.call("get_screen_size", [:])
        XCTAssertFalse(size.isError, "get_screen_size errored: \(size.rawText)")
        let match = size.rawText.range(
            of: #"Screen size: (\d+(\.\d+)?)x(\d+(\.\d+)?)"#,
            options: .regularExpression)
        XCTAssertNotNil(match,
            "get_screen_size must keep its 'Screen size: WxH' string, got: \(size.rawText)")
        let (w, h) = Self.parseScreenSize(size.rawText) ?? (1280, 800)

        // click_screen at the in-bounds screen center → legacy confirmation.
        // (click_screen reads x/y as Int — passing .double would be rejected;
        // that Int contract is itself part of the back-compat surface.)
        let response = try await harness.call("click_screen", [
            "x": .int(Int(w / 2)),
            "y": .int(Int(h / 2))
        ])
        XCTAssertFalse(response.isError,
            "click_screen at screen center should succeed: \(response.rawText)")
        XCTAssertTrue(response.rawText.hasPrefix("Clicked at ("),
            "click_screen must keep its legacy confirmation string, got: \(response.rawText)")

        for leaked in ["interaction_method", "schema_version", "decision_log", "\"ok\""] {
            XCTAssertFalse(response.rawText.contains(leaked),
                "Epic 6 key '\(leaked)' leaked into the legacy click_screen response")
        }
    }

    private static func parseScreenSize(_ text: String) -> (Double, Double)? {
        guard let r = text.range(
            of: #"(\d+(\.\d+)?)x(\d+(\.\d+)?)"#, options: .regularExpression)
        else { return nil }
        let parts = text[r].split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]), let h = Double(parts[1]) else { return nil }
        return (w, h)
    }
}
