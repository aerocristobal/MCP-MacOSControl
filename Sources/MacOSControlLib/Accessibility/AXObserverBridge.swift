import Foundation
import AppKit
import ApplicationServices

/// Opaque handle to a live `AXObserver` subscription. `cancel` is idempotent
/// and tears down both the `AXObserver` and the `CFRunLoopSource` it installed.
public protocol AXObserverSubscription: AnyObject {
    func cancel()
}

/// Wraps the bare `AXObserverCreate` / `AXObserverAddNotification` /
/// `AXObserverGetRunLoopSource` C API so the actor that multiplexes
/// subscriptions can be unit-tested without touching real UI processes.
///
/// Implementations MUST guarantee that a successful `subscribe` returns a
/// handle whose `cancel` removes BOTH the observer's notification registration
/// AND the run loop source — otherwise the server leaks observers, which
/// crashes the process when the observed application later quits.
public protocol AXObserverBridge: AnyObject {

    /// Whether the host process is currently granted Accessibility permission.
    /// Reads `AXIsProcessTrusted()` in production.
    var isProcessTrusted: Bool { get }

    /// Install an AX observer on the application root for `pid` subscribed to
    /// `notification`. The handler is invoked on the main run loop with a
    /// snapshot of the firing element's attributes; the handler MUST be
    /// re-entrant safe because the same observer may be a multiplexed dispatch
    /// target for many waiters.
    func subscribe(
        pid: pid_t,
        notification: String,
        handler: @escaping (WaitForUIEvent) -> Void
    ) throws -> AXObserverSubscription
}

// MARK: - Production implementation

/// Real `AXObserverCreate`-backed bridge. Each `subscribe` call creates a
/// fresh `AXObserver` for the (pid, notification) pair; the manager is what
/// multiplexes multiple MCP callers onto a single underlying bridge
/// subscription.
public final class AXObserverBridgeImpl: AXObserverBridge {

    public init() {}

    public var isProcessTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func subscribe(
        pid: pid_t,
        notification: String,
        handler: @escaping (WaitForUIEvent) -> Void
    ) throws -> AXObserverSubscription {
        let subscription = RealSubscription(pid: pid, notification: notification, handler: handler)
        try subscription.install()
        return subscription
    }

    /// Internal subscription type — owns its observer, run-loop source, and
    /// the application element it attached to. Cancellation tears all three
    /// down in one place so call sites never partial-leak.
    fileprivate final class RealSubscription: AXObserverSubscription {
        private let pid: pid_t
        private let notification: String
        private let handler: (WaitForUIEvent) -> Void
        private var observer: AXObserver?
        private var element: AXUIElement?
        private var isInstalled = false
        private let lock = NSLock()

        init(pid: pid_t, notification: String, handler: @escaping (WaitForUIEvent) -> Void) {
            self.pid = pid
            self.notification = notification
            self.handler = handler
        }

        func install() throws {
            let appElement = AXUIElementCreateApplication(pid)
            var maybeObserver: AXObserver?
            let createStatus = AXObserverCreate(pid, axCallback, &maybeObserver)
            guard createStatus == .success, let observer = maybeObserver else {
                throw AXResolutionError(
                    detail: "AXObserverCreate failed for pid \(pid) notification \(notification)",
                    underlyingCode: createStatus.rawValue
                )
            }
            let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()
            let addStatus = AXObserverAddNotification(
                observer,
                appElement,
                notification as CFString,
                unmanagedSelf
            )
            guard addStatus == .success else {
                throw AXResolutionError(
                    detail: "AXObserverAddNotification(\(notification)) failed for pid \(pid)",
                    underlyingCode: addStatus.rawValue
                )
            }
            let source = AXObserverGetRunLoopSource(observer)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            self.observer = observer
            self.element = appElement
            self.isInstalled = true
        }

        func cancel() {
            lock.lock()
            defer { lock.unlock() }
            guard isInstalled, let observer, let element else {
                isInstalled = false
                return
            }
            AXObserverRemoveNotification(observer, element, notification as CFString)
            let source = AXObserverGetRunLoopSource(observer)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            self.observer = nil
            self.element = nil
            self.isInstalled = false
        }

        deinit {
            cancel()
        }

        fileprivate func fire(_ firingElement: AXUIElement) {
            let role = copyStringAttribute(firingElement, kAXRoleAttribute as CFString)
            let title = copyStringAttribute(firingElement, kAXTitleAttribute as CFString)
            let identifier = copyStringAttribute(firingElement, kAXIdentifierAttribute as CFString)
            let event = WaitForUIEvent(
                notification: notification,
                elementRole: role,
                elementTitle: title,
                elementIdentifier: identifier
            )
            // Hop the delivery so it runs after the AX callback returns; the
            // handler may resume continuations that touch the actor, which we
            // never want re-entering the AX run loop source synchronously.
            DispatchQueue.main.async { [handler] in handler(event) }
        }

        private func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
            var ref: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(element, attribute, &ref)
            guard status == .success else { return nil }
            let value = ref as? String
            return (value?.isEmpty == true) ? nil : value
        }
    }
}

/// Free-function callback target for `AXObserverCreate`. Rehydrates the
/// owning subscription from the user-info pointer and dispatches the event.
private func axCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else { return }
    let subscription = Unmanaged<AXObserverBridgeImpl.RealSubscription>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    subscription.fire(element)
}
