import XCTest
@testable import MacOSControlLib

final class CancellationTokenTests: XCTestCase {

    func test_init_notCancelled() {
        let token = CancellationToken()
        XCTAssertFalse(token.isCancelled)
    }

    func test_cancel_setsIsCancelled() {
        let token = CancellationToken()
        token.cancel()
        XCTAssertTrue(token.isCancelled)
    }

    func test_cancel_isIdempotent() {
        let token = CancellationToken()
        var fired = 0
        token.onCancel { fired += 1 }
        token.cancel()
        token.cancel()
        token.cancel()
        XCTAssertEqual(fired, 1, "Callback must fire exactly once across repeated cancels")
    }

    func test_onCancel_firesOnCancel() {
        let token = CancellationToken()
        var fired = false
        token.onCancel { fired = true }
        XCTAssertFalse(fired)
        token.cancel()
        XCTAssertTrue(fired)
    }

    func test_onCancel_firesSynchronouslyIfAlreadyCancelled() {
        let token = CancellationToken()
        token.cancel()
        var fired = false
        token.onCancel { fired = true }
        XCTAssertTrue(fired, "Callbacks registered after cancellation must fire synchronously")
    }

    func test_onCancel_firesEveryCallbackInOrder() {
        let token = CancellationToken()
        var order: [Int] = []
        token.onCancel { order.append(1) }
        token.onCancel { order.append(2) }
        token.onCancel { order.append(3) }
        token.cancel()
        XCTAssertEqual(order, [1, 2, 3])
    }

    func test_checkCancellation_throwsWhenCancelled() {
        let token = CancellationToken()
        XCTAssertNoThrow(try token.checkCancellation())
        token.cancel()
        XCTAssertThrowsError(try token.checkCancellation()) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func test_reason_isPreserved() {
        let token = CancellationToken(reason: "shutdown")
        XCTAssertEqual(token.reason, "shutdown")
    }

    func test_concurrentCancel_isSafe() async {
        // Sanity check: hammer cancel() from multiple tasks and confirm we only
        // observe the callback firing once and no crash.
        let token = CancellationToken()
        let counter = Counter()
        token.onCancel {
            Task { await counter.increment() }
        }
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<32 {
                group.addTask { token.cancel() }
            }
        }
        // Give the Task { } inside the callback a moment to run.
        try? await Task.sleep(nanoseconds: 50_000_000)
        let final = await counter.value
        XCTAssertEqual(final, 1)
    }

    private actor Counter {
        private(set) var value: Int = 0
        func increment() { value += 1 }
    }
}
