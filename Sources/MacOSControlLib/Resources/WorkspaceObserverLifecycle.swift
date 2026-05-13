import Foundation
import AppKit

/// Opaque handle returned by `WorkspaceObserverLifecycle.addAppActivationObserver`.
/// Identity-only — each lifecycle implementation owns the cleanup machinery
/// keyed by `id`.
public final class WorkspaceObserverToken: Hashable {
    public let id: UUID
    public init(id: UUID = UUID()) { self.id = id }

    public static func == (lhs: WorkspaceObserverToken, rhs: WorkspaceObserverToken) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Wraps `NSWorkspace.didActivateApplicationNotification` so the subscription
/// registry can install / remove the observer paired with the
/// first-subscriber / last-unsubscriber boundaries (Scenario 7 — leak guard).
public protocol WorkspaceObserverLifecycle: AnyObject {
    /// Active count is used by `MockObserverLifecycle` to assert that an
    /// observer was actually removed when the last subscriber unsubscribed.
    var activeObserverCount: Int { get }

    func addAppActivationObserver(_ handler: @escaping () -> Void) -> WorkspaceObserverToken
    func remove(_ token: WorkspaceObserverToken)
}

public final class NSWorkspaceObserverLifecycle: WorkspaceObserverLifecycle {
    private var observers: [UUID: NSObjectProtocol] = [:]
    private let lock = NSLock()

    public init() {}

    public var activeObserverCount: Int {
        lock.lock(); defer { lock.unlock() }
        return observers.count
    }

    public func addAppActivationObserver(_ handler: @escaping () -> Void) -> WorkspaceObserverToken {
        let token = WorkspaceObserverToken()
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { _ in handler() }
        lock.lock()
        observers[token.id] = observer
        lock.unlock()
        return token
    }

    public func remove(_ token: WorkspaceObserverToken) {
        lock.lock()
        let stored = observers.removeValue(forKey: token.id)
        lock.unlock()
        if let stored {
            NSWorkspace.shared.notificationCenter.removeObserver(stored)
        }
    }
}
