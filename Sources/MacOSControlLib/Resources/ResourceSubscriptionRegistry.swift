import Foundation

/// Per-URI subscription manager. Tracks clients, owns the upstream
/// `WorkspaceObserverLifecycle` (one observer per URI regardless of how many
/// clients subscribe), debounces rapid update bursts to suppress Cmd-Tab
/// flurries, and notifies all subscribers when an event fires.
///
/// Thread-safety: a single `NSLock` guards all mutable state. Handlers run
/// inside the lock to keep delivery ordering predictable; callers must not
/// call back into the registry from a handler.
public final class ResourceSubscriptionRegistry {

    public static let defaultDebounce: TimeInterval = 0.1

    public typealias UpdateHandler = ([String: Any]) -> Void
    public typealias ContentProducer = () -> [String: Any]?
    public typealias PublishSink = (String, [String: Any]) -> Void

    private struct Subscription {
        let handler: UpdateHandler
    }

    private struct URIState {
        var subscribers: [String: Subscription] = [:]
        var observer: WorkspaceObserverToken?
        var contentProducer: ContentProducer
        var pendingGeneration: UInt64 = 0
        /// Optional per-URI signal source override. When nil, the registry's
        /// default `observerLifecycle` is used. Set per URI when one
        /// resource needs additional upstream events (e.g. the
        /// `active-window-tree` resource also listens for AX focused-window
        /// changes, not just NSWorkspace app activations).
        var signalSource: WorkspaceObserverLifecycle?
    }

    private let observerLifecycle: WorkspaceObserverLifecycle
    private let dateProvider: DateProviding
    private let debounceInterval: TimeInterval
    private let publishQueue: DispatchQueue
    private let publishSink: PublishSink?
    private var states: [String: URIState] = [:]
    private let lock = NSLock()

    public init(
        observerLifecycle: WorkspaceObserverLifecycle = NSWorkspaceObserverLifecycle(),
        dateProvider: DateProviding = SystemDateProvider(),
        debounceInterval: TimeInterval = ResourceSubscriptionRegistry.defaultDebounce,
        publishQueue: DispatchQueue = DispatchQueue(label: "mcp.resource.subscription.publish"),
        publishSink: PublishSink? = nil
    ) {
        self.observerLifecycle = observerLifecycle
        self.dateProvider = dateProvider
        self.debounceInterval = debounceInterval
        self.publishQueue = publishQueue
        self.publishSink = publishSink
    }

    /// Register a default content producer for a URI. Required before
    /// `subscribe` so the registry can build the update payload when the
    /// upstream `NSWorkspace` notification fires.
    public func registerContentProducer(_ uri: String, _ producer: @escaping ContentProducer) {
        lock.lock(); defer { lock.unlock() }
        if var state = states[uri] {
            state.contentProducer = producer
            states[uri] = state
        } else {
            states[uri] = URIState(contentProducer: producer)
        }
    }

    /// Override the upstream signal source for a single URI. Pass a
    /// `CompositeEventLifecycle([NSWorkspace, AXFocusedWindow])` for the
    /// `active-window-tree` URI so within-app window switches also produce
    /// update notifications.
    public func registerSignalSource(_ uri: String, _ source: WorkspaceObserverLifecycle) {
        lock.lock(); defer { lock.unlock() }
        if var state = states[uri] {
            state.signalSource = source
            states[uri] = state
        } else {
            states[uri] = URIState(contentProducer: { nil }, signalSource: source)
        }
    }

    public func subscribe(_ uri: String, clientId: String, handler: @escaping UpdateHandler) {
        lock.lock()
        guard var state = states[uri] else {
            lock.unlock()
            preconditionFailure("subscribe called on URI '\(uri)' before registerContentProducer")
        }
        let wasEmpty = state.subscribers.isEmpty
        state.subscribers[clientId] = Subscription(handler: handler)
        if wasEmpty && state.observer == nil {
            let source = state.signalSource ?? observerLifecycle
            state.observer = source.addAppActivationObserver { [weak self] in
                self?.schedulePublish(uri: uri)
            }
        }
        states[uri] = state
        lock.unlock()
    }

    public func unsubscribe(_ uri: String, clientId: String) {
        lock.lock()
        guard var state = states[uri] else {
            lock.unlock()
            return
        }
        state.subscribers[clientId] = nil
        var tokenToRemove: (WorkspaceObserverLifecycle, WorkspaceObserverToken)?
        if state.subscribers.isEmpty, let token = state.observer {
            let source = state.signalSource ?? observerLifecycle
            tokenToRemove = (source, token)
            state.observer = nil
        }
        states[uri] = state
        lock.unlock()
        if let (source, token) = tokenToRemove {
            source.remove(token)
        }
    }

    /// Active subscriber count for a URI. Surface for tests + diagnostics.
    public func subscriberCount(_ uri: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return states[uri]?.subscribers.count ?? 0
    }

    /// Synchronous publish helper used by unit tests to skip the dispatch hop.
    public func publish(uri: String, content: [String: Any]) {
        let subscribers: [Subscription]
        lock.lock()
        subscribers = Array(states[uri]?.subscribers.values ?? Dictionary<String, Subscription>().values)
        lock.unlock()
        for subscriber in subscribers {
            subscriber.handler(content)
        }
        publishSink?(uri, content)
    }

    /// Schedule a debounced publish for `uri`. Invoked from the upstream
    /// observer; multiple invocations inside `debounceInterval` collapse to a
    /// single delivery using the latest content snapshot.
    public func schedulePublish(uri: String) {
        lock.lock()
        guard var state = states[uri] else { lock.unlock(); return }
        state.pendingGeneration &+= 1
        let generation = state.pendingGeneration
        states[uri] = state
        let interval = debounceInterval
        lock.unlock()

        publishQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.firePendingPublish(uri: uri, generation: generation)
        }
    }

    private func firePendingPublish(uri: String, generation: UInt64) {
        lock.lock()
        guard let state = states[uri], state.pendingGeneration == generation else {
            lock.unlock()
            return
        }
        let producer = state.contentProducer
        let subscribers = Array(state.subscribers.values)
        lock.unlock()

        guard let content = producer() else { return }
        for subscriber in subscribers {
            subscriber.handler(content)
        }
        publishSink?(uri, content)
    }
}
