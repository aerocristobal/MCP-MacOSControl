import Foundation

/// STORY-018 — Multiplexes N MCP waiters onto a single underlying
/// `NSWorkspace` notification observer per `(event, bundle_id_filter)` tuple.
///
/// Lifecycle invariants (validated by `NSWorkspaceEventBridgeTests`):
/// - First waiter for a key installs the observer; subsequent waiters reuse it
///   (one underlying observer for N callers).
/// - A matching notification resumes every waiter for that key with the same
///   `AppLifecycleEvent`, then tears the subscription down.
/// - Timeout removes only the timed-out waiter; the subscription stays alive
///   while other waiters remain and is torn down when the last one leaves.
/// - `removeObserver` runs on every termination path (fire, timeout) and is
///   idempotent — no dangling observers.
/// - A nil `bundleIdentifierFilter` is a wildcard: the first event of any
///   identity resolves (Story Q2). Q5: subscribe-and-wait only; current state
///   is never inspected.
public actor NSWorkspaceEventBridge {

    public struct Key: Hashable {
        public let event: AppEventType
        public let bundleIdentifierFilter: String?
        public init(event: AppEventType, bundleIdentifierFilter: String?) {
            self.event = event
            self.bundleIdentifierFilter = bundleIdentifierFilter
        }
    }

    private struct WaiterRecord {
        let id: UUID
        let continuation: CheckedContinuation<AppLifecycleEvent, Error>
    }

    private final class SubscriptionState {
        let key: Key
        let token: AppNotificationToken
        var waiters: [UUID: WaiterRecord]

        init(key: Key, token: AppNotificationToken, waiters: [UUID: WaiterRecord]) {
            self.key = key
            self.token = token
            self.waiters = waiters
        }
    }

    private let center: AppNotificationCenter
    private var subscriptions: [Key: SubscriptionState] = [:]

    public init(notificationCenter: AppNotificationCenter) {
        self.center = notificationCenter
    }

    /// Suspend until `event` fires for an application matching
    /// `bundleIdentifierFilter` (or any application when nil), or `timeout`
    /// seconds elapse — whichever happens first. STORY-027 — also races a
    /// caller-driven cancellation.
    public func wait(
        event: AppEventType,
        bundleIdentifierFilter: String?,
        timeout: TimeInterval,
        cancellation: CancellationToken?
    ) async throws -> AppLifecycleEvent {
        // Fast-path: pre-cancelled token never attaches.
        if cancellation?.isCancelled == true {
            throw CancellationError()
        }

        let key = Key(event: event, bundleIdentifierFilter: bundleIdentifierFilter)
        let waiterID = UUID()
        let start = Date()

        return try await withCheckedThrowingContinuation { continuation in
            // Register cancellation BEFORE the attach task so a cancel that
            // arrives mid-attach collapses to attach-then-remove via the
            // actor's serialised state.
            cancellation?.onCancel { [weak self] in
                guard let self else { return }
                Task { await self.cancelWaiter(key: key, waiterID: waiterID) }
            }
            Task {
                await self.attach(
                    key: key,
                    waiterID: waiterID,
                    continuation: continuation,
                    timeout: timeout,
                    start: start,
                    cancellation: cancellation
                )
            }
        }
    }

    // MARK: - Internal state transitions (all actor-isolated)

    private func attach(
        key: Key,
        waiterID: UUID,
        continuation: CheckedContinuation<AppLifecycleEvent, Error>,
        timeout: TimeInterval,
        start: Date,
        cancellation: CancellationToken?
    ) async {
        // STORY-027 — cancel-before-attach race: cancel-task may have run
        // first and found no state. Resume the continuation here so the
        // observer is never installed.
        if cancellation?.isCancelled == true {
            continuation.resume(throwing: CancellationError())
            return
        }

        let record = WaiterRecord(id: waiterID, continuation: continuation)

        if let existing = subscriptions[key] {
            existing.waiters[waiterID] = record
        } else {
            let token = center.addObserver(forName: key.event.notificationName) { [weak self] payload in
                guard let self else { return }
                Task { await self.dispatch(payload, key: key) }
            }
            subscriptions[key] = SubscriptionState(
                key: key,
                token: token,
                waiters: [waiterID: record]
            )
        }

        // Race a per-waiter timeout. If it wins, surface AppEventWaitTimeoutError
        // and remove just this waiter; other waiters on the same key continue.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(start)
            await self.removeWaiter(key: key, waiterID: waiterID, elapsedSeconds: elapsed)
        }
    }

    private func dispatch(_ payload: AppNotificationPayload, key: Key) {
        guard let state = subscriptions[key] else { return }
        // Wildcard (nil filter) matches any identity; otherwise the bundle id
        // must match exactly.
        if let filter = key.bundleIdentifierFilter,
           payload.bundleIdentifier != filter {
            return
        }

        let event = AppLifecycleEvent(
            eventType: key.event,
            bundleIdentifier: payload.bundleIdentifier,
            pid: payload.pid,
            localizedName: payload.localizedName
        )
        let waiters = state.waiters
        state.waiters.removeAll()
        for waiter in waiters.values {
            waiter.continuation.resume(returning: event)
        }
        tearDown(key: key)
    }

    private func removeWaiter(key: Key, waiterID: UUID, elapsedSeconds: Double) {
        guard let state = subscriptions[key],
              let record = state.waiters.removeValue(forKey: waiterID) else { return }

        record.continuation.resume(throwing: AppEventWaitTimeoutError(
            event: key.event.rawValue,
            bundleIdentifierFilter: key.bundleIdentifierFilter,
            elapsedSeconds: elapsedSeconds
        ))

        if state.waiters.isEmpty {
            tearDown(key: key)
        }
    }

    /// STORY-027 — remove a single waiter due to caller cancellation. Shared
    /// observers stay alive while other waiters remain (their continuations
    /// keep waiting); the underlying NSWorkspace observer is torn down only
    /// when the last waiter on this key leaves.
    private func cancelWaiter(key: Key, waiterID: UUID) {
        guard let state = subscriptions[key],
              let record = state.waiters.removeValue(forKey: waiterID) else { return }

        record.continuation.resume(throwing: CancellationError())

        if state.waiters.isEmpty {
            tearDown(key: key)
        }
    }

    private func tearDown(key: Key) {
        guard let state = subscriptions.removeValue(forKey: key) else { return }
        center.removeObserver(state.token)
    }
}
