import XCTest
import MCP
@testable import MacOSControlLib

final class RealtimeModuleTests: XCTestCase {
    // All 4 realtime tools have no required params, so no param validation tests
    func testUnknownToolReturnsNil() async throws {
        let result = try await RealtimeModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
