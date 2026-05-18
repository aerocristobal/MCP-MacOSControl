import Foundation
import AppKit

/// STORY-008 — Notifies `AXObserverManager` when an observed application
/// terminates so pending waiters can be failed with
/// `target_application_terminated` instead of dangling forever.
///
/// Distinct from `WorkspaceObserverLifecycle` (STORY-013) which watches app
/// *activation*; this protocol exposes only the `didTerminate` side-channel
/// keyed by pid.
public protocol WorkspaceTerminationObserver: AnyObject {
    func observeTermination(
        of pid: pid_t,
        handler: @escaping (_ bundleIdentifier: String?) -> Void
    ) -> WorkspaceTerminationSubscription
}

public protocol WorkspaceTerminationSubscription: AnyObject {
    func cancel()
}

public final class NSWorkspaceTerminationObserver: WorkspaceTerminationObserver {

    public init() {}

    public func observeTermination(
        of pid: pid_t,
        handler: @escaping (String?) -> Void
    ) -> WorkspaceTerminationSubscription {
        let token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: nil
        ) { notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.processIdentifier == pid
            else { return }
            handler(app.bundleIdentifier)
        }
        return Subscription(token: token)
    }

    private final class Subscription: WorkspaceTerminationSubscription {
        private var token: NSObjectProtocol?

        init(token: NSObjectProtocol) {
            self.token = token
        }

        func cancel() {
            guard let token else { return }
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            self.token = nil
        }

        deinit { cancel() }
    }
}
