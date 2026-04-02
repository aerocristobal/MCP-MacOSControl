import XCTest
import MCP
@testable import MacOSControlLib

final class ContinuousCaptureModuleTests: XCTestCase {
    func testStartContinuousCaptureMissingParams() async throws {
        let result = try await ContinuousCaptureModule.handle(makeParams(name: "start_continuous_capture"))
        XCTAssertEqual(result?.isError, true)
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await ContinuousCaptureModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
