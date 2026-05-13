import Foundation
@testable import MacOSControlLib

final class MockWorkspaceObserverLifecycle: WorkspaceObserverLifecycle {
    private var handlers: [UUID: () -> Void] = [:]

    var activeObserverCount: Int { handlers.count }

    func addAppActivationObserver(_ handler: @escaping () -> Void) -> WorkspaceObserverToken {
        let token = WorkspaceObserverToken()
        handlers[token.id] = handler
        return token
    }

    func remove(_ token: WorkspaceObserverToken) {
        handlers.removeValue(forKey: token.id)
    }

    /// Simulates an upstream `didActivateApplicationNotification` reaching all
    /// registered handlers.
    func fireActivation() {
        for handler in handlers.values {
            handler()
        }
    }
}
