import Foundation
import MCP

/// STORY-009 — `wait_for_element_state` polled until timeout without the
/// element reaching the requested state. Carries the last observed state so the
/// agent can see how far off it was without an extra round-trip.
///
/// `InvalidConditionExpressionError`, `TimeoutExceedsMaximumError` (STORY-008,
/// reused with a 120 s cap) and `AccessibilityPermissionRequiredError`
/// (STORY-008, reused) cover the other failure modes.
public struct StateConditionNotMetError: Error, CustomStringConvertible, LocalizedError {
    public let condition: String
    public let currentState: [String: Any]?
    public let elapsedSeconds: Double
    public let pollsPerformed: Int
    public let errorCode: String = "state_condition_not_met"

    public init(
        condition: String,
        currentState: [String: Any]?,
        elapsedSeconds: Double,
        pollsPerformed: Int
    ) {
        self.condition = condition
        self.currentState = currentState
        self.elapsedSeconds = elapsedSeconds
        self.pollsPerformed = pollsPerformed
    }

    public var description: String {
        "\(errorCode): condition \"\(condition)\" not met within "
            + "\(String(format: "%.2f", elapsedSeconds))s (\(pollsPerformed) polls)"
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        var details: [String: Any] = [
            "condition": condition,
            "elapsed_seconds": elapsedSeconds,
            "polls_performed": pollsPerformed
        ]
        details["current_state"] = currentState ?? ["exists": false]
        return MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: details
        )
    }
}
