import XCTest
import MCP
@testable import MacOSControlLib

final class AXResolverErrorsTests: XCTestCase {

    func test_axNotFoundError_descriptionIncludesCriteria() {
        let error = AXNotFoundError(searchCriteria: "role=AXButton, title=Save")
        XCTAssertTrue(error.description.contains("AX_NOT_FOUND"))
        XCTAssertTrue(error.description.contains("role=AXButton"))
        XCTAssertTrue(error.description.contains("title=Save"))
        XCTAssertEqual(error.errorDescription, error.description)
        XCTAssertEqual(error.errorCode, "AX_NOT_FOUND")
    }

    func test_axNotFoundError_toResultIsErrorTrue() {
        let error = AXNotFoundError(searchCriteria: "role=AXButton")
        let result = error.toResult()
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(result.content.isEmpty)
    }

    func test_axResolutionError_descriptionIncludesDetail() {
        let error = AXResolutionError(detail: "windows lookup failed", underlyingCode: -25204)
        XCTAssertTrue(error.description.contains("AX_RESOLUTION_FAILED"))
        XCTAssertTrue(error.description.contains("windows lookup failed"))
        XCTAssertEqual(error.errorDescription, error.description)
        XCTAssertEqual(error.errorCode, "AX_RESOLUTION_FAILED")
    }

    func test_axResolutionError_toResultIsErrorTrue() {
        let error = AXResolutionError(detail: "boom")
        let result = error.toResult()
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(result.content.isEmpty)
    }

    func test_axResolutionError_descriptionDoesNotLeakUnderlyingCode() {
        // AX_RESOLUTION_FAILED message must NOT include the raw integer underlying code.
        let error = AXResolutionError(detail: "boom", underlyingCode: -25204)
        XCTAssertFalse(error.description.contains("-25204"),
                       "Underlying AXError code must not leak into client-visible description")
    }
}
