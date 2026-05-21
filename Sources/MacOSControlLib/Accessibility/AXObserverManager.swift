import Foundation

/// STORY-008 — Multiplexes N MCP waiters onto a single underlying
/// `AXObserver` per `(pid, notification)` pair.
///
/// Lifecycle invariants (validated by the AXObserverManagerTests scaffold):
/// - First waiter for a key installs the AX subscription AND a
///   `NSWorkspace.didTerminate` observer for the same pid.
/// - Subsequent waiters reuse the existing subscription (1 underlying observer
///   for N callers).
/// - Notification firing resumes every waiter for that key with the same
///   `WaitForUIEvent`, then tears down the subscription.
/// - Application termination resumes every waiter for that pid with
///   `TargetApplicationTerminatedError` and tears down every subscription
///   for that pid.
/// - Timeout removes the timed-out waiter only; the underlying subscription
///   stays alive while other waiters remain, and is torn down when the last
///   waiter resolves.
/// - Cancellation never leaves a dangling `AXObserver` or `CFRunLoopSource`.
public actor AXObserverManager {

    public struct Key: Hashable {
        public let pid: pid_t
        public let notification: String
        public init(pid: pid_t, notification: String) {
            self.pid = pid
            self.notification = notification
        }
    }

    private struct WaiterRecord {
        let id: UUID
        let continuation: CheckedContinuation<WaitForUIEvent, Error>
    }

    private final class SubscriptionState {
        let key: Key
        var observer: AXObserverSubscription
        var termination: WorkspaceTerminationSubscription
        var waiters: [UUID: WaiterRecord]

        init(
            key: Key,
            observer: AXObserverSubscription,
            termination: WorkspaceTerminationSubscription,
            waiters: [UUID: WaiterRecord]
        ) {
            self.key = key
            self.observer = observer
            self.termination = termination
            self.waiters = waiters
        }
    }

    private let axBridge: AXObserverBridge
    private let workspace: WorkspaceTerminationObserver
    private var subscriptions: [Key: SubscriptionState] = [:]

    public init(axBridge: AXObserverBridge, workspace: WorkspaceTerminationObserver) {
        self.axBridge = axBridge
        self.workspace = workspace
    }

    public func canSubscribe() -> Bool {
        axBridge.isProcessTrusted
    }

    /// Suspend until `notification` fires for `pid`, the target application
    /// terminates, or `timeout` seconds elapse — whichever happens first.
    /// STORY-027 — pass a `cancellation` token to also race a caller-driven
    /// cancellation; on cancel the waiter is removed and the continuation
    /// resumes with `CancellationError`.
    public func wait(
        for notification: String,
        in pid: pid_t,
        timeout: TimeInterval,
        cancellation: CancellationToken?
    ) async throws -> WaitForUIEvent {
        guard axBridge.isProcessTrusted else {
            throw AccessibilityPermissionRequiredError()
        }

        // Fast-path: pre-cancelled token short-circuits before we attach.
        if cancellation?.isCancelled == true {
            throw CancellationError()
        }

        let key = Key(pid: pid, notification: notification)
        let waiterID = UUID()
        let start = Date()

        // Race the notification, termination, timeout, and cancellation. Whoever
        // finishes first wins; the loser's branch becomes a no-op via the
        // once-only continuation contract.
        return try await withCheckedThrowingContinuation { continuation in
            // Register the cancellation hook BEFORE the Task that installs the
            // AX subscription. The actor serialises attach + cancel, so a
            // cancel that arrives mid-install collapses to install-then-remove.
            cancellation?.onCancel { [weak self] in
                guard let self else { return }
                Task { await self.removeWaiter(key: key, waiterID: waiterID, reason: .cancelled) }
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
        continuation: CheckedContinuation<WaitForUIEvent, Error>,
        timeout: TimeInterval,
        start: Date,
        cancellation: CancellationToken?
    ) async {
        // STORY-027 — cancel-before-attach race: if the caller cancelled while
        // the install Task was queued on the actor, the cancel-task already
        // ran and found no state to remove. Resume the continuation with
        // CancellationError here so the waiter does not get installed.
        if cancellation?.isCancelled == true {
            continuation.resume(throwing: CancellationError())
            return
        }

        let record = WaiterRecord(id: waiterID, continuation: continuation)

        if let existing = subscriptions[key] {
            existing.waiters[waiterID] = record
        } else {
            do {
                let observer = try axBridge.subscribe(
                    pid: key.pid,
                    notification: key.notification
                ) { [weak self] event in
                    guard let self else { return }
                    Task { await self.dispatchEvent(event, key: key) }
                }
                let termination = workspace.observeTermination(of: key.pid) { [weak self] bundleId in
                    guard let self else { return }
                    Task { await self.dispatchTermination(key: key, bundleIdentifier: bundleId) }
                }
                subscriptions[key] = SubscriptionState(
                    key: key,
                    observer: observer,
                    termination: termination,
                    waiters: [waiterID: record]
                )
            } catch {
                continuation.resume(throwing: error)
                return
            }
        }

        // Race a per-waiter timeout. If it wins, we surface WaitTimeoutError
        // and remove just this waiter; other waiters on the same key continue.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(start)
            await self.removeWaiter(
                key: key,
                waiterID: waiterID,
                reason: .timeout(elapsedSeconds: elapsed)
            )
        }
    }

    private func dispatchEvent(_ event: WaitForUIEvent, key: Key) {
        guard let state = subscriptions[key] else { return }
        let waiters = state.waiters
        state.waiters.removeAll()
        for record in waiters.values {
            record.continuation.resume(returning: event)
        }
        tearDown(key: key)
    }

    private func dispatchTermination(key: Key, bundleIdentifier: String?) {
        // Termination is per-pid: every subscription on this pid (regardless
        // of notification) must fail, not just the one that happened to be
        // looked up first.
        let affected = subscriptions.filter { $0.key.pid == key.pid }
        for (subKey, state) in affected {
            let waiters = state.waiters
            state.waiters.removeAll()
            let error = TargetApplicationTerminatedError(
                pid: subKey.pid,
                bundleIdentifier: bundleIdentifier
            )
            for record in waiters.values {
                record.continuation.resume(throwing: error)
            }
            tearDown(key: subKey)
        }
    }

    private enum RemovalReason {
        case timeout(elapsedSeconds: Double)
        /// STORY-027 — caller cancelled the wait via notifications/cancelled
        /// or server shutdown. Continuation resumes with `CancellationError`.
        case cancelled
    }

    private func removeWaiter(key: Key, waiterID: UUID, reason: RemovalReason) {
        guard let state = subscriptions[key],
              let record = state.waiters.removeValue(forKey: waiterID) else { return }

        switch reason {
        case .timeout(let elapsed):
            record.continuation.resume(throwing: WaitTimeoutError(
                notification: key.notification,
                elapsedSeconds: elapsed
            ))
        case .cancelled:
            record.continuation.resume(throwing: CancellationError())
        }

        if state.waiters.isEmpty {
            tearDown(key: key)
        }
    }

    private func tearDown(key: Key) {
        guard let state = subscriptions.removeValue(forKey: key) else { return }
        state.observer.cancel()
        state.termination.cancel()
    }
}
