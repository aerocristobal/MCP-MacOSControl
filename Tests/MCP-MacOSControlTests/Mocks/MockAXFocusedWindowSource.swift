import Foundation
@testable import MacOSControlLib

final class MockAXFocusedWindowSource: AXFocusedWindowSource {
    let pid: pid_t
    var handler: () -> Void
    private(set) var isStarted: Bool = false
    private(set) var startCount: Int = 0
    private(set) var stopCount: Int = 0

    init(pid: pid_t, handler: @escaping () -> Void) {
        self.pid = pid
        self.handler = handler
    }

    func start() {
        isStarted = true
        startCount += 1
    }

    func stop() {
        isStarted = false
        stopCount += 1
    }

    func fireFocusedWindowChange() {
        handler()
    }
}

final class MockAXFocusedWindowSourceFactory: AXFocusedWindowSourceFactory {
    private(set) var createdSources: [MockAXFocusedWindowSource] = []
    private(set) var requestedPIDs: [pid_t] = []

    var latest: MockAXFocusedWindowSource? { createdSources.last }

    func makeSource(forPID pid: pid_t, handler: @escaping () -> Void) -> AXFocusedWindowSource {
        requestedPIDs.append(pid)
        let source = MockAXFocusedWindowSource(pid: pid, handler: handler)
        createdSources.append(source)
        return source
    }
}
