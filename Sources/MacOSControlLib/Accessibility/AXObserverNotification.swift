import Foundation

/// STORY-008 — Supported AX notification names accepted by `wait_for_ui_event`.
///
/// The set is closed: requests naming an unknown notification short-circuit at
/// the tool layer with `unsupported_notification`. The same list is exposed to
/// agents via the `ax_observer_notifications` MCP prompt so they don't have to
/// guess.
public enum AXObserverNotification {

    public static let supported: [String] = [
        "AXWindowCreated",
        "AXUIElementDestroyed",
        "AXFocusedUIElementChanged",
        "AXValueChanged",
        "AXSelectedTextChanged",
        "AXTitleChanged",
        "AXMainWindowChanged",
        "AXFocusedWindowChanged"
    ]

    public static func isSupported(_ name: String) -> Bool {
        supported.contains(name)
    }
}

/// Observed AX event delivered by `AXObserverBridge` to `AXObserverManager`.
///
/// Element attributes are cached at delivery time so consumers can still report
/// them when the underlying `AXUIElement` has already been destroyed (Q6:
/// reading attributes from a dead element is undefined).
public struct WaitForUIEvent: Sendable, Equatable {
    public let notification: String
    public let elementRole: String?
    public let elementTitle: String?
    public let elementIdentifier: String?

    public init(
        notification: String,
        elementRole: String? = nil,
        elementTitle: String? = nil,
        elementIdentifier: String? = nil
    ) {
        self.notification = notification
        self.elementRole = elementRole
        self.elementTitle = elementTitle
        self.elementIdentifier = elementIdentifier
    }
}
