import Foundation
import AppKit

/// STORY-018 — the minimal seam over `NSWorkspace.shared.notificationCenter`
/// so `NSWorkspaceEventBridge` can be unit-tested against a fake without a
/// real running application. Parallel in spirit to STORY-008's
/// `AXObserverBridge` / `WorkspaceTerminationObserver` seams: the testable
/// actor lives in `NSWorkspaceEventBridge.swift`; the untestable Apple-API
/// glue lives here, exactly as `AXObserverBridge.swift` is split from
/// `AXObserverManager.swift`.
public struct AppNotificationPayload: Sendable {
    public let bundleIdentifier: String?
    public let pid: pid_t
    public let localizedName: String?

    public init(bundleIdentifier: String?, pid: pid_t, localizedName: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.pid = pid
        self.localizedName = localizedName
    }
}

public protocol AppNotificationToken: AnyObject {}

public protocol AppNotificationCenter: AnyObject {
    func addObserver(
        forName name: Notification.Name,
        handler: @escaping (AppNotificationPayload) -> Void
    ) -> AppNotificationToken
    func removeObserver(_ token: AppNotificationToken)
}

/// Production `AppNotificationCenter` backed by the real workspace center.
/// Extracts the `NSRunningApplication` carried in every NSWorkspace
/// application-lifecycle notification.
public final class NSWorkspaceNotificationCenter: AppNotificationCenter {

    public init() {}

    private final class Token: AppNotificationToken {
        let observer: NSObjectProtocol
        init(observer: NSObjectProtocol) { self.observer = observer }
    }

    public func addObserver(
        forName name: Notification.Name,
        handler: @escaping (AppNotificationPayload) -> Void
    ) -> AppNotificationToken {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: name,
            object: nil,
            queue: nil
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
            handler(AppNotificationPayload(
                bundleIdentifier: app.bundleIdentifier,
                pid: app.processIdentifier,
                localizedName: app.localizedName
            ))
        }
        return Token(observer: observer)
    }

    public func removeObserver(_ token: AppNotificationToken) {
        guard let token = token as? Token else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(token.observer)
    }
}
