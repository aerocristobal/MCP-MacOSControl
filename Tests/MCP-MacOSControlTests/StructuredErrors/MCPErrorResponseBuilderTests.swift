// STORY: STORY-016 — Structured Error Response Contract
// COMPONENT: MCPErrorResponseBuilder

import XCTest
import MCP
@testable import MacOSControlLib

final class MCPErrorResponseBuilderTests: XCTestCase {

    var builder: MCPErrorResponseBuilder!

    override func setUp() {
        super.setUp()
        // Touch shared registry to force lazy bootstrap. Tests use it implicitly via
        // the DEBUG assert path inside builder.build(...).
        _ = ErrorCodeRegistry.shared.allRegistrations().count
        builder = MCPErrorResponseBuilder()
    }

    // MARK: - Scenario 1: Response shape

    func test_build_returnsResultWithIsErrorTrue() {
        let result = builder.build(code: "permission_denied", message: "Accessibility permission required")
        XCTAssertEqual(result.isError, true)
    }

    func test_build_emitsCodeMessageAndDetails_asWrappedJSON() throws {
        let result = builder.build(
            code: "coordinates_out_of_bounds",
            message: "x=5000 outside display bounds",
            details: ["display_bounds": ["x": 0, "y": 0, "width": 1920, "height": 1080]]
        )
        let inner = try result.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "coordinates_out_of_bounds")
        XCTAssertEqual(inner["message"] as? String, "x=5000 outside display bounds")
        let details = inner["details"] as? [String: Any]
        XCTAssertNotNil(details?["display_bounds"])
    }

    func test_build_omitsDetailsKey_whenDetailsNil() throws {
        let result = builder.build(code: "permission_denied", message: "denied")
        let inner = try result.parseStructuredError()
        XCTAssertNil(inner["details"], "details key must be omitted when no details are provided")
    }

    func test_build_omitsDetailsKey_whenDetailsEmpty() throws {
        let result = builder.build(code: "permission_denied", message: "denied", details: [:])
        let inner = try result.parseStructuredError()
        XCTAssertNil(inner["details"], "empty details dict must be omitted to keep payloads tight")
    }

    func test_build_envelopeHasOkFalse() throws {
        let result = builder.build(code: "permission_denied", message: "denied")
        // Pull the raw text and re-parse outer envelope to confirm ok=false.
        var rawText: String?
        for content in result.content {
            if case .text(let text, _, _) = content { rawText = text }
        }
        let data = try XCTUnwrap(rawText?.data(using: .utf8))
        let outer = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(outer["ok"] as? Bool, false)
        XCTAssertNotNil(outer["error"])
    }

    // MARK: - Scenario 6: Unknown error mapping

    func test_buildFromUnknown_mapsArbitraryErrorToInternalError() throws {
        struct UnexpectedError: Error { let detail = "oh no" }
        let result = builder.buildFromUnknown(UnexpectedError())
        let inner = try result.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "internal_error")
        let details = inner["details"] as? [String: Any]
        XCTAssertEqual(details?["swift_error_type"] as? String, "UnexpectedError")
    }

    func test_buildFromUnknown_doesNotLeakUserPaths() throws {
        struct UnexpectedError: Error, CustomStringConvertible {
            var description: String { "failed reading /Users/secret/private/file.swift at line 42" }
        }
        let result = builder.buildFromUnknown(UnexpectedError())
        let inner = try result.parseStructuredError()
        let message = (inner["message"] as? String) ?? ""
        XCTAssertFalse(message.contains("/Users/"),
                       "internal_error responses must scrub /Users/ file paths from the message")
        XCTAssertFalse(message.contains("/Users/secret"),
                       "internal_error responses must not leak full paths")
    }

    func test_buildFromUnknown_doesNotLeakPrivatePaths() throws {
        struct UnexpectedError: Error, CustomStringConvertible {
            var description: String { "AX error on /private/var/folders/aa/bb/T/cache" }
        }
        let result = builder.buildFromUnknown(UnexpectedError())
        let inner = try result.parseStructuredError()
        let message = (inner["message"] as? String) ?? ""
        XCTAssertFalse(message.contains("/private/"))
        XCTAssertFalse(message.contains("/var/folders"))
    }

    func test_buildFromUnknown_setsIsErrorTrue() {
        struct E: Error {}
        XCTAssertEqual(builder.buildFromUnknown(E()).isError, true)
    }
}
