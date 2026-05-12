import XCTest
import MCP
@testable import MacOSControlLib

/// STORY-011 Scenario 6 — verify `enum` constraints on parameters that accept
/// a fixed set of values. These catch agent typos at the schema layer instead
/// of letting them silently fall through to the tool implementation's default.
final class SchemaEnumAuditTests: XCTestCase {

    // MARK: - Mouse button enums

    func test_clickScreen_buttonParam_declaresEnum() throws {
        let allowed = try enumValues(toolName: "click_screen", param: "button")
        XCTAssertEqual(Set(allowed), Set(["left", "right", "middle"]))
    }

    func test_mouseDown_buttonParam_declaresEnum() throws {
        let allowed = try enumValues(toolName: "mouse_down", param: "button")
        XCTAssertEqual(Set(allowed), Set(["left", "right", "middle"]))
    }

    func test_mouseUp_buttonParam_declaresEnum() throws {
        let allowed = try enumValues(toolName: "mouse_up", param: "button")
        XCTAssertEqual(Set(allowed), Set(["left", "right", "middle"]))
    }

    // MARK: - Scroll direction enum

    func test_scroll_directionParam_declaresEnum() throws {
        let allowed = try enumValues(toolName: "scroll", param: "direction")
        XCTAssertEqual(Set(allowed), Set(["up", "down", "left", "right"]))
    }

    // MARK: - Capture type enum (shared across several modules)

    func test_startContinuousCapture_captureType_declaresEnum() throws {
        let allowed = try enumValues(toolName: "start_continuous_capture", param: "capture_type")
        XCTAssertEqual(Set(allowed), Set(["display", "window", "application"]))
    }

    func test_analyzeScreenNow_captureType_declaresEnum() throws {
        let allowed = try enumValues(toolName: "analyze_screen_now", param: "capture_type")
        XCTAssertEqual(Set(allowed), Set(["display", "window", "application"]))
    }

    func test_startScreenMonitoring_captureType_declaresEnum() throws {
        let allowed = try enumValues(toolName: "start_screen_monitoring", param: "capture_type")
        XCTAssertEqual(Set(allowed), Set(["display", "window", "application"]))
    }

    func test_analyzeScreenWithLlm_captureType_declaresEnum() throws {
        let allowed = try enumValues(toolName: "analyze_screen_with_llm", param: "capture_type")
        XCTAssertEqual(Set(allowed), Set(["display", "window", "application"]))
    }

    func test_intelligentScreenSummary_captureType_declaresEnum() throws {
        let allowed = try enumValues(toolName: "intelligent_screen_summary", param: "capture_type")
        XCTAssertEqual(Set(allowed), Set(["display", "window", "application"]))
    }

    // MARK: - iPhone modifier-keys enum (array items)

    func test_iphonePressKey_modifiersParam_declaresEnumViaItems() throws {
        let prop = try schemaProperty(toolName: "iphone_press_key", param: "modifiers")
        guard case .object(let items)? = prop["items"] else {
            XCTFail("iphone_press_key.modifiers missing 'items' object")
            return
        }
        guard case .array(let enumValues)? = items["enum"] else {
            XCTFail("iphone_press_key.modifiers.items missing 'enum' array")
            return
        }
        let strings = enumValues.compactMap { value -> String? in
            if case .string(let s) = value { return s }
            return nil
        }
        let allowed = Set(strings)
        XCTAssertTrue(allowed.contains("cmd"),    "modifier enum missing 'cmd'")
        XCTAssertTrue(allowed.contains("shift"),  "modifier enum missing 'shift'")
        XCTAssertTrue(allowed.contains("ctrl"),   "modifier enum missing 'ctrl'")
        XCTAssertTrue(allowed.contains("alt"),    "modifier enum missing 'alt'")
        XCTAssertTrue(allowed.contains("option"), "modifier enum missing 'option'")
    }

    // MARK: - Scenario 6 — parameter descriptions reference the enum vocabulary

    /// Every parameter that declares an `enum` must also name those allowed
    /// values in its description text, so that an LLM reading the schema can
    /// reason about the contract without parsing the JSON structure. This walks
    /// the entire catalog rather than enumerating fixed tool / param pairs so
    /// new enum constraints get audited automatically.
    func test_everyEnumParam_lists_allowedValues_inDescription() {
        for tool in ToolRouter.allTools {
            guard case .object(let root) = tool.inputSchema,
                  case .object(let props)? = root["properties"] else { continue }

            for (paramName, propertyValue) in props {
                guard case .object(let prop) = propertyValue else { continue }
                let allowed = enumValues(in: prop)
                guard !allowed.isEmpty else { continue }

                let description: String
                if case .string(let text)? = prop["description"] {
                    description = text
                } else {
                    description = ""
                }

                for value in allowed {
                    XCTAssertTrue(
                        description.contains(value),
                        "\(tool.name).\(paramName) declares enum value '\(value)' but does not name it in the description: \"\(description)\""
                    )
                }
            }
        }
    }

    /// Scenario 5 — optional parameters that declare a `default:` in the schema
    /// should explain that default in the description so an MCP client can
    /// reason about the resting behavior without re-reading the schema.
    func test_paramsWithDefaults_mention_defaultIn_description() {
        for tool in ToolRouter.allTools {
            guard case .object(let root) = tool.inputSchema,
                  case .object(let props)? = root["properties"] else { continue }

            for (paramName, propertyValue) in props {
                guard case .object(let prop) = propertyValue, prop["default"] != nil else { continue }

                let description: String
                if case .string(let text)? = prop["description"] {
                    description = text
                } else {
                    description = ""
                }

                XCTAssertTrue(
                    description.localizedCaseInsensitiveContains("default"),
                    "\(tool.name).\(paramName) declares a default in the schema but does not explain it in the description: \"\(description)\""
                )
            }
        }
    }

    // MARK: - Helpers

    private func enumValues(in prop: [String: Value]) -> [String] {
        if case .array(let direct)? = prop["enum"] {
            return direct.compactMap { value in
                if case .string(let s) = value { return s }
                return nil
            }
        }
        // Array-of-enum shape (e.g. iphone_press_key.modifiers)
        if case .object(let items)? = prop["items"], case .array(let nested)? = items["enum"] {
            return nested.compactMap { value in
                if case .string(let s) = value { return s }
                return nil
            }
        }
        return []
    }

    private func enumValues(toolName: String, param: String) throws -> [String] {
        let prop = try schemaProperty(toolName: toolName, param: param)
        guard case .array(let values)? = prop["enum"] else {
            XCTFail("\(toolName).\(param) missing 'enum' array")
            return []
        }
        return values.compactMap { value in
            if case .string(let s) = value { return s }
            return nil
        }
    }

    private func schemaProperty(toolName: String, param: String) throws -> [String: Value] {
        guard let tool = ToolRouter.allTools.first(where: { $0.name == toolName }) else {
            throw XCTSkip("\(toolName) not registered")
        }
        guard case .object(let root) = tool.inputSchema,
              case .object(let props)? = root["properties"],
              case .object(let prop)? = props[param] else {
            XCTFail("\(toolName).\(param) schema shape unexpected")
            throw XCTSkip("schema shape unexpected for \(toolName).\(param)")
        }
        return prop
    }
}
