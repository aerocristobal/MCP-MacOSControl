import Foundation
import ApplicationServices
import MCP

public final class ElementAtPositionTool {
    private let bridge: AXApplicationBridge
    private let translator: DisplayCoordinateTranslator
    private let validator: DisplayBoundsValidator
    private let treeBuilder: AccessibilityTreeBuilder
    private let serializer: AXNodeSerializer
    private let permissionsChecker: () -> Bool

    public init(
        bridge: AXApplicationBridge,
        translator: DisplayCoordinateTranslator,
        validator: DisplayBoundsValidator,
        treeBuilder: AccessibilityTreeBuilder,
        serializer: AXNodeSerializer = AXNodeSerializer(),
        permissionsChecker: @escaping () -> Bool = { AXIsProcessTrusted() }
    ) {
        self.bridge = bridge
        self.translator = translator
        self.validator = validator
        self.treeBuilder = treeBuilder
        self.serializer = serializer
        self.permissionsChecker = permissionsChecker
    }

    public func execute(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]

        guard let x = args["x"]?.doubleValue else {
            return errorResult(code: "invalid_coordinates", message: "x is required and must be a number")
        }
        guard let y = args["y"]?.doubleValue else {
            return errorResult(code: "invalid_coordinates", message: "y is required and must be a number")
        }
        let displayIndex = args["display_index"]?.intValue

        let global: CGPoint
        do {
            global = try translator.toGlobal(x: CGFloat(x), y: CGFloat(y), displayIndex: displayIndex)
        } catch let err as UnknownDisplayIndexError {
            return errorResult(code: "unknown_display_index", message: err.description)
        } catch {
            return errorResult(code: "unknown_display_index", message: error.localizedDescription)
        }

        do {
            try validator.validate(x: global.x, y: global.y)
        } catch let err as InvalidCoordinatesError {
            return errorResult(code: "invalid_coordinates", message: err.detail)
        } catch let err as CoordinatesOutOfBoundsError {
            let bounds = err.unionBounds
            let detail = "(\(err.x), \(err.y)) is outside display union " +
                "[origin=(\(Int(bounds.origin.x)), \(Int(bounds.origin.y))), " +
                "size=\(Int(bounds.width))x\(Int(bounds.height))]"
            return MCPErrorResponseBuilder.shared.build(
                code: "coordinates_out_of_bounds",
                message: detail,
                details: [
                    "display_bounds": [
                        "x": Int(bounds.origin.x),
                        "y": Int(bounds.origin.y),
                        "width": Int(bounds.width),
                        "height": Int(bounds.height)
                    ]
                ]
            )
        } catch {
            return errorResult(code: "coordinates_out_of_bounds", message: error.localizedDescription)
        }

        guard permissionsChecker() else {
            return MacOSControlLib.MCPError.accessibilityPermissionRequired.toStructuredResult()
        }

        let ref: AXElementReference?
        do {
            ref = try bridge.copyElementAtPosition(globalX: global.x, globalY: global.y)
        } catch let mcp as MCPError {
            switch mcp {
            case .permissionDenied:
                return MacOSControlLib.MCPError.accessibilityPermissionRequired.toStructuredResult()
            default:
                return mcp.toStructuredResult()
            }
        } catch {
            return errorResult(code: "ax_resolution_failed", message: error.localizedDescription)
        }

        guard let resolved = ref else {
            return errorResult(
                code: "element_not_found",
                message: "no AX element returned for (\(global.x), \(global.y))"
            )
        }

        let node = treeBuilder.buildShallow(from: resolved)
        var payload = serializer.serializeRoot(node)
        if node.role == "AXApplication" {
            payload["note"] = "no interactive element was found at these coordinates"
        }

        let text = jsonString(payload) ?? "{}"
        return .init(content: [.text(text)], isError: false)
    }

    private func errorResult(code: String, message: String) -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(code: code, message: message)
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
