import Foundation
import AppKit
import ApplicationServices
import MCP

/// STORY-009 — `wait_for_element_state` MCP tool. Polls the AX tree at a fixed
/// cadence until a resolved element matches a parsed `condition`, or the
/// timeout elapses. The documented fallback to `wait_for_ui_event` (STORY-008)
/// for transitions outside the AXObserver notification vocabulary.
public final class WaitForElementStateTool {
    public typealias PIDResolver = (_ application: String) -> (pid_t, String?)?
    public typealias ProbeFactory = (
        _ locator: ElementLocator,
        _ pid: pid_t,
        _ needsViewport: Bool
    ) -> ElementStateProbe

    public static let defaultTimeoutSeconds: TimeInterval = 30
    public static let maxTimeoutSeconds: TimeInterval = 120
    public static let defaultPollIntervalMs = 100

    private let parser = ConditionExpressionParser()
    private let pollLoop = ElementStatePollLoop()
    private let serializer = AXNodeSerializer()

    private let probeFactory: ProbeFactory
    private let clock: Clock
    private let pidResolver: PIDResolver
    private let permissionCheck: () -> Bool
    private let pollIntervalMs: Int

    public init(
        probeFactory: @escaping ProbeFactory,
        clock: Clock = SystemClock(),
        pidResolver: PIDResolver? = nil,
        permissionCheck: @escaping () -> Bool = { AXIsProcessTrusted() },
        pollIntervalMs: Int = WaitForElementStateTool.defaultPollIntervalMs
    ) {
        self.probeFactory = probeFactory
        self.clock = clock
        self.pidResolver = pidResolver ?? Self.defaultPIDResolver
        self.permissionCheck = permissionCheck
        self.pollIntervalMs = pollIntervalMs
    }

    public func execute(_ params: CallTool.Parameters) async -> CallTool.Result {
        let args = params.arguments ?? [:]

        // `condition` wins; legacy `state` is accepted as a one-version alias (Q5).
        let conditionText = (args["condition"]?.stringValue
            ?? args["state"]?.stringValue)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let conditionText, !conditionText.isEmpty else {
            return MCPErrorResponseBuilder.shared.build(
                code: "invalid_input",
                message: "wait_for_element_state requires 'condition'"
            )
        }

        // Timeout cap and condition parse run BEFORE the permission/app gates so
        // a malformed request gets the precise, self-correcting error fastest.
        let requestedTimeout = args["timeout_seconds"]?.doubleValue ?? Self.defaultTimeoutSeconds
        guard requestedTimeout <= Self.maxTimeoutSeconds else {
            return TimeoutExceedsMaximumError(
                requested: requestedTimeout,
                maximum: Self.maxTimeoutSeconds
            ).toStructuredResult()
        }
        let timeout = max(0, requestedTimeout)

        let parsed: ParsedCondition
        do {
            parsed = try parser.parse(conditionText)
        } catch let invalid as InvalidConditionExpressionError {
            return invalid.toStructuredResult()
        } catch {
            return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
        }

        guard permissionCheck() else {
            return AccessibilityPermissionRequiredError().toStructuredResult()
        }

        guard let application = args["application"]?.stringValue, !application.isEmpty else {
            return MCPErrorResponseBuilder.shared.build(
                code: "invalid_input",
                message: "wait_for_element_state requires 'application'"
            )
        }
        guard let (pid, _) = pidResolver(application) else {
            return MCPErrorResponseBuilder.shared.build(
                code: "application_not_found",
                message: "Application '\(application)' not found"
            )
        }

        let locator = extractLocator(from: args)
        let probe = probeFactory(locator, pid, parsed.field == .visibleInViewport)
        let predicate = ConditionPredicate(parsed)

        let outcome = await pollLoop.poll(
            predicate: predicate,
            probe: probe,
            timeout: timeout,
            pollIntervalMs: pollIntervalMs,
            clock: clock
        )

        switch outcome {
        case let .satisfied(last, elapsed, polls):
            return successResult(
                last: last, elapsedSeconds: elapsed, polls: polls
            )
        case let .timedOut(last, elapsed, polls):
            let currentState: [String: Any]?
            if case .matched(let node) = last {
                currentState = serializer.serialize(node)
            } else {
                currentState = nil
            }
            return StateConditionNotMetError(
                condition: conditionText,
                currentState: currentState,
                elapsedSeconds: elapsed,
                pollsPerformed: polls
            ).toStructuredResult()
        }
    }

    // MARK: - Locator handling (parallel to wait_for_ui_event)

    private func extractLocator(from args: [String: Value]) -> ElementLocator {
        if case .object(let nested) = args["element_locator"] ?? .null {
            return ElementLocator(
                role: nested["role"]?.stringValue,
                title: nested["title"]?.stringValue,
                identifier: nested["identifier"]?.stringValue,
                label: nested["label"]?.stringValue,
                description: nested["description"]?.stringValue
            )
        }
        return ElementLocator(
            role: args["role"]?.stringValue,
            title: args["title"]?.stringValue,
            identifier: args["identifier"]?.stringValue,
            label: args["label"]?.stringValue,
            description: args["description"]?.stringValue
        )
    }

    // MARK: - Response

    private func successResult(
        last: ElementProbeResult,
        elapsedSeconds: TimeInterval,
        polls: Int
    ) -> CallTool.Result {
        var payload: [String: Any] = [
            "schema_version": AXNodeSerializer.schemaVersion,
            "condition_met": true,
            "elapsed_seconds": elapsedSeconds,
            "polls_performed": polls
        ]
        switch last {
        case .matched(let node):
            payload["element"] = serializer.serialize(node)
        case .notFound:
            // Symmetric `exists = false` success: the element is gone.
            payload["exists"] = false
        }
        let text = jsonString(payload) ?? "{}"
        return .init(content: [.text(text)], isError: false)
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Default PID resolver (shared shape with wait_for_ui_event)

    private static let defaultPIDResolver: PIDResolver = { application in
        let workspace = NSWorkspace.shared
        let isBundleId = application.contains(".")
        for app in workspace.runningApplications {
            if isBundleId, app.bundleIdentifier == application {
                return (app.processIdentifier, app.bundleIdentifier)
            }
            if !isBundleId,
               app.localizedName?.localizedCaseInsensitiveContains(application) == true {
                return (app.processIdentifier, app.bundleIdentifier)
            }
        }
        return nil
    }
}
