import Foundation
import MCP
import CoreGraphics

// STORY-010 — `smart_interact` MCP tool surface. Validates the intent-first
// input, hands it to the InteractionRouter, and serializes the router verdict
// (success payload + decision_log, or a STORY-016 structured error).
public final class SmartInteractTool {

    private let router: InteractionRouting

    public init(router: InteractionRouting) {
        self.router = router
    }

    public func execute(_ params: CallTool.Parameters) async -> CallTool.Result {
        let args = params.arguments ?? [:]

        guard let intentRaw = args["intent"]?.stringValue, !intentRaw.isEmpty else {
            return MCPErrorResponseBuilder.shared.build(
                code: "missing_required_field",
                message: "smart_interact requires 'intent'",
                details: ["field": "intent"])
        }
        guard let intent = InteractionIntent(rawValue: intentRaw) else {
            return MCPErrorResponseBuilder.shared.build(
                code: "unsupported_intent",
                message: "Unsupported intent '\(intentRaw)'. v1 supports: click, type.",
                details: [
                    "intent": intentRaw,
                    "supported": InteractionIntent.allCases.map(\.rawValue)
                ])
        }

        let value = args["value"]?.stringValue
        if intent == .type, value == nil || value?.isEmpty == true {
            return MCPErrorResponseBuilder.shared.build(
                code: "missing_required_field",
                message: "smart_interact with intent=type requires 'value'",
                details: ["field": "value"])
        }

        let input = SmartInteractInput(
            intent: intent,
            targetDescription: args["target_description"]?.stringValue,
            application: args["application"]?.stringValue,
            coordinates: parseCoordinates(args["coordinates"]),
            value: value,
            skipLayers: args["skip_layers"]?.arrayValue?.compactMap(\.stringValue) ?? [])

        let result = await router.route(input: input)

        if result.isError {
            return MCPErrorResponseBuilder.shared.build(
                code: result.errorCode ?? "all_layers_failed",
                message: "smart_interact: every eligible interaction layer was skipped or failed",
                details: result.details)
        }

        var payload: [String: Any] = [
            "ok": true,
            "interaction_method": result.interactionMethod,
            "confidence": result.confidence,
            "decision_log": result.decisionLog.map(\.asDictionary),
            "result": result.result
        ]
        if result.interactionMethod == "coordinate_fallback" {
            payload["warning"] = "coordinate-based interaction is the least reliable layer — it breaks when windows move or layouts change. Verify the effect with wait_for_* before relying on it."
        }
        let text = jsonString(payload) ?? "{\"ok\":true}"
        return .init(content: [.text(text)], isError: false)
    }

    private func parseCoordinates(_ value: Value?) -> CGPoint? {
        guard let object = value?.objectValue,
              let x = object["x"]?.doubleValue,
              let y = object["y"]?.doubleValue else { return nil }
        return CGPoint(x: x, y: y)
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
