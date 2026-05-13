import Foundation

/// Surfaces "focused window changed in the currently frontmost application"
/// as a `WorkspaceObserverLifecycle` event. Internally:
///   1. Subscribes to NSWorkspace app-activation so it knows when to
///      re-target the AX observer to the new frontmost pid.
///   2. Holds a per-pid `AXFocusedWindowSource` that fires whenever the AX
///      `kAXFocusedWindowChangedNotification` is delivered for that pid.
///
/// Closes the Scenario 4 (STORY-013) gap: within-app window switches —
/// which NSWorkspace does NOT surface — now produce a focused-window
/// signal that the subscription registry can publish.
public final class AXFocusedWindowSignalLifecycle: WorkspaceObserverLifecycle {

    private let workspaceLifecycle: WorkspaceObserverLifecycle
    private let workspaceProvider: WorkspaceProvider
    private let sourceFactory: AXFocusedWindowSourceFactory

    private var subscribers: [UUID: () -> Void] = [:]
    private var workspaceToken: WorkspaceObserverToken?
    private var currentSource: AXFocusedWindowSource?
    private var currentPID: pid_t?
    private let lock = NSLock()

    public init(workspaceLifecycle: WorkspaceObserverLifecycle,
                workspaceProvider: WorkspaceProvider,
                sourceFactory: AXFocusedWindowSourceFactory) {
        self.workspaceLifecycle = workspaceLifecycle
        self.workspaceProvider = workspaceProvider
        self.sourceFactory = sourceFactory
    }

    public var activeObserverCount: Int {
        lock.lock(); defer { lock.unlock() }
        return subscribers.count
    }

    public func addAppActivationObserver(_ handler: @escaping () -> Void) -> WorkspaceObserverToken {
        let token = WorkspaceObserverToken()
        var sourceToStart: AXFocusedWindowSource?

        lock.lock()
        let wasEmpty = subscribers.isEmpty
        subscribers[token.id] = handler
        if wasEmpty {
            workspaceToken = workspaceLifecycle.addAppActivationObserver { [weak self] in
                self?.handleAppActivation()
            }
            sourceToStart = makeAndStoreSourceForCurrentApp_locked()
        }
        lock.unlock()

        sourceToStart?.start()
        return token
    }

    public func remove(_ token: WorkspaceObserverToken) {
        var workspaceTokenToRemove: WorkspaceObserverToken?
        var sourceToStop: AXFocusedWindowSource?

        lock.lock()
        subscribers.removeValue(forKey: token.id)
        if subscribers.isEmpty {
            workspaceTokenToRemove = workspaceToken
            workspaceToken = nil
            sourceToStop = currentSource
            currentSource = nil
            currentPID = nil
        }
        lock.unlock()

        if let workspaceTokenToRemove {
            workspaceLifecycle.remove(workspaceTokenToRemove)
        }
        sourceToStop?.stop()
    }

    /// Synchronously test-visible: tests inject a `MockAXFocusedWindowSource`
    /// and assert the AX observer is dropped when the last subscriber leaves.
    public var hasActiveAXSource: Bool {
        lock.lock(); defer { lock.unlock() }
        return currentSource != nil
    }

    // MARK: - Internals

    private func handleAppActivation() {
        var oldSource: AXFocusedWindowSource?
        var newSource: AXFocusedWindowSource?
        var handlersToFire: [() -> Void] = []

        lock.lock()
        let newPID = workspaceProvider.frontmostApplication?.processIdentifier
        if newPID != currentPID {
            oldSource = currentSource
            currentSource = nil
            currentPID = nil
            newSource = makeAndStoreSourceForCurrentApp_locked()
            // App switch is itself a "focused window changed" event from the
            // subscriber's perspective — fire handlers so the registry can
            // schedule an update for the new app's window.
            handlersToFire = Array(subscribers.values)
        }
        lock.unlock()

        oldSource?.stop()
        newSource?.start()
        for handler in handlersToFire { handler() }
    }

    /// Builds and stores the AX source for the current frontmost app. Caller
    /// must hold `lock`; the returned source is NOT started — the caller
    /// must call `start()` after releasing the lock to avoid re-entrant AX
    /// callbacks under the lock.
    private func makeAndStoreSourceForCurrentApp_locked() -> AXFocusedWindowSource? {
        guard let pid = workspaceProvider.frontmostApplication?.processIdentifier else {
            return nil
        }
        let source = sourceFactory.makeSource(forPID: pid) { [weak self] in
            self?.deliverFocusedWindowEvent()
        }
        currentSource = source
        currentPID = pid
        return source
    }

    private func deliverFocusedWindowEvent() {
        lock.lock()
        let handlers = Array(subscribers.values)
        lock.unlock()
        for handler in handlers { handler() }
    }
}
