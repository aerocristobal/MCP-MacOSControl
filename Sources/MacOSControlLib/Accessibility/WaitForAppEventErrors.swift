import Foundation
import MCP

// STORY-018 error types. Each maps to a code registered in
// `ErrorCodeBootstrap` and renders through `MCPErrorResponseBuilder` so the
// wrapped JSON envelope contract from STORY-016 is preserved.

/// Timeout while waiting for an NSWorkspace lifecycle event. Shares the
/// `wait_timeout` code with STORY-008 (confirmed via the `ErrorCodeRegistry`
/// collision check) but carries app-event-shaped details.
public struct AppEventWaitTimeoutError: Error, CustomStringConvertible, LocalizedError {
    public let event: String
    public let bundleIdentifierFilter: String?
    public let elapsedSeconds: Double
    public let errorCode: String = "wait_timeout"

    public init(event: String, bundleIdentifierFilter: String?, elapsedSeconds: Double) {
        self.event = event
        self.bundleIdentifierFilter = bundleIdentifierFilter
        self.elapsedSeconds = elapsedSeconds
    }

    public var description: String {
        let target = bundleIdentifierFilter ?? "(any application)"
        return "\(errorCode): app event '\(event)' for \(target) did not fire within \(String(format: "%.2f", elapsedSeconds))s"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        var details: [String: Any] = [
            "event": event,
            "elapsed_seconds": elapsedSeconds
        ]
        if let bundleIdentifierFilter {
            details["bundle_id_filter"] = bundleIdentifierFilter
        }
        return MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: details
        )
    }
}

public struct UnsupportedAppEventError: Error, CustomStringConvertible, LocalizedError {
    public let event: String
    public let supported: [String]
    public let errorCode: String = "unsupported_app_event"

    public init(event: String, supported: [String] = AppEventType.supported) {
        self.event = event
        self.supported = supported
    }

    public var description: String {
        "\(errorCode): event '\(event)' is not in the supported set"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: [
                "event": event,
                "supported_events": supported
            ]
        )
    }
}

public struct InvalidBundleIdentifierError: Error, CustomStringConvertible, LocalizedError {
    public let bundleIdentifier: String
    public let errorCode: String = "invalid_bundle_identifier"

    /// Apple reverse-DNS pattern (Story Q6).
    public static let pattern = "^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$"

    public init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }

    public var description: String {
        "\(errorCode): '\(bundleIdentifier)' is not a valid reverse-DNS bundle identifier"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: [
                "bundle_identifier": bundleIdentifier,
                "bundle_identifier_pattern": Self.pattern
            ]
        )
    }
}
