import Foundation
import ApplicationServices

/// Per-pid handle on an AX `kAXFocusedWindowChangedNotification` observer.
/// `start` installs the underlying `AXObserver`; `stop` tears it down.
/// Lifecycle is one-shot: do not call `start` again after `stop`.
public protocol AXFocusedWindowSource: AnyObject {
    func start()
    func stop()
}

/// Factory so the parent lifecycle can build a new source each time the
/// frontmost app's pid changes (an `AXObserver` is bound to a single pid).
public protocol AXFocusedWindowSourceFactory: AnyObject {
    func makeSource(forPID pid: pid_t, handler: @escaping () -> Void) -> AXFocusedWindowSource
}

public final class AXFocusedWindowSourceFactoryImpl: AXFocusedWindowSourceFactory {
    public init() {}

    public func makeSource(forPID pid: pid_t, handler: @escaping () -> Void) -> AXFocusedWindowSource {
        AXFocusedWindowSourceImpl(pid: pid, handler: handler)
    }
}

private func axObserverCallback(_ observer: AXObserver,
                                _ element: AXUIElement,
                                _ notification: CFString,
                                _ userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo else { return }
    let unmanaged = Unmanaged<AXFocusedWindowSourceImpl>.fromOpaque(userInfo)
    let source = unmanaged.takeUnretainedValue()
    source.fireHandler()
}

final class AXFocusedWindowSourceImpl: AXFocusedWindowSource {
    private let pid: pid_t
    private let handler: () -> Void
    private var observer: AXObserver?
    private var element: AXUIElement?
    private var isStarted = false

    init(pid: pid_t, handler: @escaping () -> Void) {
        self.pid = pid
        self.handler = handler
    }

    deinit {
        stop()
    }

    func fireHandler() {
        // Hop to the main queue so callbacks observe a stable AX state and
        // never re-enter the AX run-loop source synchronously.
        DispatchQueue.main.async { [handler] in handler() }
    }

    func start() {
        guard !isStarted else { return }
        let appElement = AXUIElementCreateApplication(pid)
        var maybeObserver: AXObserver?
        let createStatus = AXObserverCreate(pid, axObserverCallback, &maybeObserver)
        guard createStatus == .success, let observer = maybeObserver else {
            MCPLogger.warn("AXObserverCreate failed for pid \(pid) (status \(createStatus.rawValue))")
            return
        }
        let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()
        let addStatus = AXObserverAddNotification(
            observer,
            appElement,
            kAXFocusedWindowChangedNotification as CFString,
            unmanagedSelf
        )
        guard addStatus == .success else {
            MCPLogger.warn("AXObserverAddNotification failed for pid \(pid) (status \(addStatus.rawValue))")
            return
        }
        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        self.observer = observer
        self.element = appElement
        self.isStarted = true
    }

    func stop() {
        guard isStarted, let observer, let element else {
            isStarted = false
            return
        }
        AXObserverRemoveNotification(observer, element, kAXFocusedWindowChangedNotification as CFString)
        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        self.observer = nil
        self.element = nil
        self.isStarted = false
    }
}
