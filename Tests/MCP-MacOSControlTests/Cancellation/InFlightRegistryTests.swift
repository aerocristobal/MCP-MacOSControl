import XCTest
@testable import MacOSControlLib

final class InFlightRegistryTests: XCTestCase {

    func test_register_then_cancel_firesToken() async {
        let registry = InFlightRegistry()
        let token = CancellationToken()
        var fired = false
        token.onCancel { fired = true }
        await registry.register(requestId: "req-1", token: token)
        let didCancel = await registry.cancel(requestId: "req-1")
        XCTAssertTrue(didCancel)
        XCTAssertTrue(fired)
        XCTAssertTrue(token.isCancelled)
    }

    func test_cancel_unknownRequestId_returnsFalse() async {
        let registry = InFlightRegistry()
        let didCancel = await registry.cancel(requestId: "nonexistent")
        XCTAssertFalse(didCancel)
    }

    func test_cancel_removesEntry_doubleCancelReturnsFalse() async {
        let registry = InFlightRegistry()
        let token = CancellationToken()
        await registry.register(requestId: "req-2", token: token)
        _ = await registry.cancel(requestId: "req-2")
        let second = await registry.cancel(requestId: "req-2")
        XCTAssertFalse(second, "Second cancel for the same id must be a no-op")
    }

    func test_finish_removesEntry() async {
        let registry = InFlightRegistry()
        let token = CancellationToken()
        await registry.register(requestId: "req-3", token: token)
        let before = await registry.count()
        XCTAssertEqual(before, 1)
        await registry.finish(requestId: "req-3")
        let after = await registry.count()
        XCTAssertEqual(after, 0)
    }

    func test_finish_unknownRequestId_isNoOp() async {
        let registry = InFlightRegistry()
        await registry.finish(requestId: "nonexistent")
        let count = await registry.count()
        XCTAssertEqual(count, 0)
    }

    func test_cancelAll_cancelsEveryToken() async {
        let registry = InFlightRegistry()
        let tokens = (0..<5).map { _ in CancellationToken() }
        for (i, token) in tokens.enumerated() {
            await registry.register(requestId: "req-\(i)", token: token)
        }
        let before = await registry.count()
        XCTAssertEqual(before, 5)
        await registry.cancelAll()
        let after = await registry.count()
        XCTAssertEqual(after, 0)
        for token in tokens {
            XCTAssertTrue(token.isCancelled)
        }
    }

    func test_register_replacesExisting() async {
        // Defensive: if a caller registers the same id twice (shouldn't happen
        // in production), the latest token wins. Validates we don't leak the
        // old one without cancelling it deliberately.
        let registry = InFlightRegistry()
        let first = CancellationToken()
        let second = CancellationToken()
        await registry.register(requestId: "req-x", token: first)
        await registry.register(requestId: "req-x", token: second)
        let count = await registry.count()
        XCTAssertEqual(count, 1)
        _ = await registry.cancel(requestId: "req-x")
        XCTAssertFalse(first.isCancelled, "First token is not the one held by the registry anymore")
        XCTAssertTrue(second.isCancelled)
    }
}
