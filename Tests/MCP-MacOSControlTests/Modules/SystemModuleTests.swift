import XCTest
import MCP
@testable import MacOSControlLib

final class SystemModuleTests: XCTestCase {
    func testWaitMillisecondsMissingParams() async throws {
        let result = try await SystemModule.handle(makeParams(name: "wait_milliseconds"))
        XCTAssertEqual(result?.isError, true)
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await SystemModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
