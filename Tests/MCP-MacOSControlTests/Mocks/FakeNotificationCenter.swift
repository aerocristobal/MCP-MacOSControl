import Foundation
@testable import MacOSControlLib

/// STORY-018 test double for `AppNotificationCenter`. Records registrations so
/// tests can assert one-observer-per-key multiplexing and zero leaks, and
/// exposes `fire*` helpers to simulate NSWorkspace notifications without a real
/// running application.
final class FakeNotificationCenter: AppNotificationCenter, @unchecked Sendable {

    private final class Token: AppNotificationToken {
        let id = UUID()
        let name: Notification.Name
        let handler: (AppNotificationPayload) -> Void
        init(name: Notification.Name, handler: @escaping (AppNotificationPayload) -> Void) {
            self.name = name
            self.handler = handler
        }
    }

    private let lock = NSLock()
    private var tokens: [UUID: Token] = [:]
    private(set) var removeObserverCallCount = 0

    var activeObserverCount: Int {
        lock.lock(); defer { lock.unlock() }
        return tokens.count
    }

    func observerCount(for event: AppEventType) -> Int {
        lock.lock(); defer { lock.unlock() }
        return tokens.values.filter { $0.name == event.notificationName }.count
    }

    func addObserver(
        forName name: Notification.Name,
        handler: @escaping (AppNotificationPayload) -> Void
    ) -> AppNotificationToken {
        let token = Token(name: name, handler: handler)
        lock.lock()
        tokens[token.id] = token
        lock.unlock()
        return token
    }

    func removeObserver(_ token: AppNotificationToken) {
        guard let token = token as? Token else { return }
        lock.lock()
        if tokens.removeValue(forKey: token.id) != nil {
            removeObserverCallCount += 1
        }
        lock.unlock()
    }

    // MARK: - Firing helpers

    func fire(_ event: AppEventType, bundleId: String?, pid: pid_t, name: String?) {
        let payload = AppNotificationPayload(
            bundleIdentifier: bundleId,
            pid: pid,
            localizedName: name
        )
        lock.lock()
        let handlers = tokens.values
            .filter { $0.name == event.notificationName }
            .map(\.handler)
        lock.unlock()
        for handler in handlers { handler(payload) }
    }

    func fireLaunched(bundleId: String?, pid: pid_t, name: String?) {
        fire(.launched, bundleId: bundleId, pid: pid, name: name)
    }
}
