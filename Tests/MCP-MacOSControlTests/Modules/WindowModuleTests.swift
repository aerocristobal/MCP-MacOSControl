import XCTest
import MCP
@testable import MacOSControlLib

final class WindowModuleTests: XCTestCase {
    func testActivateWindowMissingParams() async throws {
        let result = try await WindowModule.handle(makeParams(name: "activate_window"))
        XCTAssertEqual(result?.isError, true)
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await WindowModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
