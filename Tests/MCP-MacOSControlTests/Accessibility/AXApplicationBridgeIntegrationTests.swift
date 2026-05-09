import XCTest
@testable import MacOSControlLib

// NOTE: These tests exercise (or stand in for) the real AX C API. Most assertions
// require accessibility permissions granted to the test runner and a known fixture
// app launched by the host. They are gated by the CI_MACOS_INTEGRATION env var.
// The construction smoke test runs unconditionally because it does not touch AX.
final class AXApplicationBridgeIntegrationTests: XCTestCase {

    func test_bridgeImpl_canBeConstructedWithoutPermissions() {
        let bridge = AXApplicationBridgeImpl()
        // Construction is permission-free; runningApplications() does not require AX trust.
        let apps = bridge.runningApplications()
        XCTAssertFalse(apps.isEmpty, "Expected at least one running application on a live macOS host")
    }

    func test_bridgeImpl_returnsEmptyWindowsForUnknownPID() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CI_MACOS_INTEGRATION"] == "true",
            "Integration tests gated on CI_MACOS_INTEGRATION=true"
        )
        let bridge = AXApplicationBridgeImpl()
        // PID 0 is the kernel; AX windows query should not crash. Expect either an
        // empty list or a thrown AXResolutionError — never a fatal error.
        let result = (try? bridge.windows(forPID: 0)) ?? []
        XCTAssertTrue(result.isEmpty)
    }
}
