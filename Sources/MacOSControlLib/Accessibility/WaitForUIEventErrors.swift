import Foundation
import MCP

// STORY-008 error types. Each maps to a code registered in
// `ErrorCodeBootstrap` and renders through `MCPErrorResponseBuilder` so the
// wrapped JSON envelope contract from STORY-016 is preserved.

public struct WaitTimeoutError: Error, CustomStringConvertible, LocalizedError {
    public let notification: String
    public let elapsedSeconds: Double
    public let errorCode: String = "wait_timeout"

    public init(notification: String, elapsedSeconds: Double) {
        self.notification = notification
        self.elapsedSeconds = elapsedSeconds
    }

    public var description: String {
        "\(errorCode): \(notification) did not fire within \(String(format: "%.2f", elapsedSeconds))s"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: [
                "notification": notification,
                "elapsed_seconds": elapsedSeconds
            ]
        )
    }
}

public struct TargetApplicationTerminatedError: Error, CustomStringConvertible, LocalizedError {
    public let pid: pid_t
    public let bundleIdentifier: String?
    public let errorCode: String = "target_application_terminated"

    public init(pid: pid_t, bundleIdentifier: String?) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
    }

    public var description: String {
        "\(errorCode): target application (pid \(pid), bundle \(bundleIdentifier ?? "?")) terminated before the notification fired"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        var details: [String: Any] = ["pid": Int(pid)]
        if let bundleIdentifier {
            details["bundle_identifier"] = bundleIdentifier
        }
        return MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: details
        )
    }
}

public struct AccessibilityPermissionRequiredError: Error, CustomStringConvertible, LocalizedError {
    public let errorCode: String = "accessibility_permission_required"

    public init() {}

    public var description: String {
        "\(errorCode): \(MCPError.accessibilityPermissionRequired.message)"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        MCPError.accessibilityPermissionRequired.toStructuredResult()
    }
}

public struct UnsupportedNotificationError: Error, CustomStringConvertible, LocalizedError {
    public let notification: String
    public let supported: [String]
    public let errorCode: String = "unsupported_notification"

    public init(notification: String, supported: [String] = AXObserverNotification.supported) {
        self.notification = notification
        self.supported = supported
    }

    public var description: String {
        "\(errorCode): notification '\(notification)' is not in the supported set"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: [
                "notification": notification,
                "supported_notifications": supported
            ]
        )
    }
}

public struct TimeoutExceedsMaximumError: Error, CustomStringConvertible, LocalizedError {
    public let requested: TimeInterval
    public let maximum: TimeInterval
    public let errorCode: String = "timeout_exceeds_maximum"

    public init(requested: TimeInterval, maximum: TimeInterval) {
        self.requested = requested
        self.maximum = maximum
    }

    public var description: String {
        "\(errorCode): requested timeout \(requested)s exceeds maximum \(maximum)s — use MCP Resources subscription for long-lived watches"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: [
                "requested_seconds": requested,
                "maximum_seconds": maximum
            ]
        )
    }
}
