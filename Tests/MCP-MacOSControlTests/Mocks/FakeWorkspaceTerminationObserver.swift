import Foundation
@testable import MacOSControlLib

/// In-memory `WorkspaceTerminationObserver` so tests can drive the
/// `target_application_terminated` path without quitting a real app.
final class FakeWorkspaceTerminationObserver: WorkspaceTerminationObserver {

    fileprivate final class FakeSubscription: WorkspaceTerminationSubscription {
        let pid: pid_t
        let handler: (String?) -> Void
        weak var observer: FakeWorkspaceTerminationObserver?
        var isCancelled = false

        init(pid: pid_t, handler: @escaping (String?) -> Void, observer: FakeWorkspaceTerminationObserver) {
            self.pid = pid
            self.handler = handler
            self.observer = observer
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            observer?.didCancel(self)
        }
    }

    private var subscriptions: [ObjectIdentifier: FakeSubscription] = [:]

    func observeTermination(
        of pid: pid_t,
        handler: @escaping (String?) -> Void
    ) -> WorkspaceTerminationSubscription {
        let sub = FakeSubscription(pid: pid, handler: handler, observer: self)
        subscriptions[ObjectIdentifier(sub)] = sub
        return sub
    }

    fileprivate func didCancel(_ sub: FakeSubscription) {
        subscriptions.removeValue(forKey: ObjectIdentifier(sub))
    }

    /// Trigger every subscription pinned to `pid`.
    func fireTerminated(pid: pid_t, bundleId: String?) {
        for sub in subscriptions.values where sub.pid == pid {
            sub.handler(bundleId)
        }
    }

    var activeSubscriptionCount: Int { subscriptions.count }
}
