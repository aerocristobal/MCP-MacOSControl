import Foundation
import AppKit

/// STORY-018 — friendly, agent-facing application lifecycle event vocabulary.
///
/// Raw `NSWorkspace.did…ApplicationNotification` constants are an Apple SDK
/// implementation detail; agents speak in these friendly names and the mapping
/// to `Notification.Name` stays internal (Story Q1).
public enum AppEventType: String, CaseIterable, Sendable {
    case launched
    case activated
    case terminated
    case deactivated
    case hidden
    case unhidden

    /// Friendly name → the `NSWorkspace` notification that backs it.
    public var notificationName: Notification.Name {
        switch self {
        case .launched: return NSWorkspace.didLaunchApplicationNotification
        case .activated: return NSWorkspace.didActivateApplicationNotification
        case .terminated: return NSWorkspace.didTerminateApplicationNotification
        case .deactivated: return NSWorkspace.didDeactivateApplicationNotification
        case .hidden: return NSWorkspace.didHideApplicationNotification
        case .unhidden: return NSWorkspace.didUnhideApplicationNotification
        }
    }

    /// The closed set surfaced to agents (and echoed in `unsupported_app_event`).
    public static let supported: [String] = AppEventType.allCases.map(\.rawValue)

    public static func isSupported(_ name: String) -> Bool {
        AppEventType(rawValue: name) != nil
    }
}

/// The resolved event handed back to a waiter when an NSWorkspace
/// notification fires. Parallel to STORY-008's `WaitForUIEvent`.
public struct AppLifecycleEvent: Sendable, Equatable {
    public let eventType: AppEventType
    public let bundleIdentifier: String?
    public let pid: pid_t
    public let localizedName: String?

    public init(
        eventType: AppEventType,
        bundleIdentifier: String?,
        pid: pid_t,
        localizedName: String?
    ) {
        self.eventType = eventType
        self.bundleIdentifier = bundleIdentifier
        self.pid = pid
        self.localizedName = localizedName
    }
}
