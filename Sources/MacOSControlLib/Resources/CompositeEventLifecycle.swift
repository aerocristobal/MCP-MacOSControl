import Foundation

/// Fan-out wrapper: a single subscription installs one observer on each
/// underlying `WorkspaceObserverLifecycle` and routes any of their events
/// to the supplied handler. Used to merge NSWorkspace app-activation +
/// AX focused-window-changed into the single upstream signal that the
/// `active-window-tree` resource subscribes to (STORY-013 Scenario 4).
public final class CompositeEventLifecycle: WorkspaceObserverLifecycle {

    private let sources: [WorkspaceObserverLifecycle]
    private var tokens: [UUID: [(WorkspaceObserverLifecycle, WorkspaceObserverToken)]] = [:]
    private let lock = NSLock()

    public init(_ sources: [WorkspaceObserverLifecycle]) {
        self.sources = sources
    }

    public var activeObserverCount: Int {
        lock.lock(); defer { lock.unlock() }
        return tokens.count
    }

    public func addAppActivationObserver(_ handler: @escaping () -> Void) -> WorkspaceObserverToken {
        let token = WorkspaceObserverToken()
        var inner: [(WorkspaceObserverLifecycle, WorkspaceObserverToken)] = []
        for source in sources {
            inner.append((source, source.addAppActivationObserver(handler)))
        }
        lock.lock()
        tokens[token.id] = inner
        lock.unlock()
        return token
    }

    public func remove(_ token: WorkspaceObserverToken) {
        lock.lock()
        let inner = tokens.removeValue(forKey: token.id) ?? []
        lock.unlock()
        for (source, t) in inner {
            source.remove(t)
        }
    }
}
