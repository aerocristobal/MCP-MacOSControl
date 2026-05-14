import XCTest
import MCP
@testable import MacOSControlLib

final class AXResolverErrorsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ErrorCodeRegistry.shared.reset()
        try? ErrorCodeBootstrap.register()
    }

    func test_axNotFoundError_descriptionIncludesCriteria() {
        let error = AXNotFoundError(searchCriteria: "role=AXButton, title=Save")
        XCTAssertTrue(error.description.contains("ax_not_found"))
        XCTAssertTrue(error.description.contains("role=AXButton"))
        XCTAssertTrue(error.description.contains("title=Save"))
        XCTAssertEqual(error.errorDescription, error.description)
        XCTAssertEqual(error.errorCode, "ax_not_found")
    }

    func test_axNotFoundError_localizedDescriptionIncludesCriteria() {
        // DoD: "AXNotFoundError carries full search criteria in localizedDescription".
        let error: Error = AXNotFoundError(searchCriteria: "role=AXButton, title=Save")
        XCTAssertTrue(error.localizedDescription.contains("role=AXButton"))
        XCTAssertTrue(error.localizedDescription.contains("title=Save"))
    }

    func test_axNotFoundError_toStructuredResult_isErrorTrue() throws {
        let error = AXNotFoundError(searchCriteria: "role=AXButton")
        let result = error.toStructuredResult()
        XCTAssertEqual(result.isError, true)
        let inner = try result.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "ax_not_found")
        let details = inner["details"] as? [String: Any]
        XCTAssertEqual(details?["search_criteria"] as? String, "role=AXButton")
    }

    func test_axResolutionError_descriptionIncludesDetail() {
        let error = AXResolutionError(detail: "windows lookup failed", underlyingCode: -25204)
        XCTAssertTrue(error.description.contains("ax_resolution_failed"))
        XCTAssertTrue(error.description.contains("windows lookup failed"))
        XCTAssertEqual(error.errorDescription, error.description)
        XCTAssertEqual(error.errorCode, "ax_resolution_failed")
    }

    func test_axResolutionError_toStructuredResult_isErrorTrue() throws {
        let error = AXResolutionError(detail: "boom")
        let result = error.toStructuredResult()
        XCTAssertEqual(result.isError, true)
        let inner = try result.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "ax_resolution_failed")
    }

    func test_axResolutionError_descriptionDoesNotLeakUnderlyingCode() {
        // ax_resolution_failed message text must NOT include the raw integer underlying code.
        // (It IS exposed structurally via details.underlying_code — agents can read it
        //  programmatically, but it stays out of the human-readable description.)
        let error = AXResolutionError(detail: "boom", underlyingCode: -25204)
        XCTAssertFalse(error.description.contains("-25204"),
                       "Underlying AXError code must not leak into client-visible description")
    }
}
