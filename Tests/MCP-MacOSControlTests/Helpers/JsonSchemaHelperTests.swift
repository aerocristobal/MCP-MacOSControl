import XCTest
import MCP
@testable import MacOSControlLib

final class JsonSchemaHelperTests: XCTestCase {
    func testEmptyObjectSchema() {
        let schema = jsonSchema(type: "object")
        guard case .object(let dict) = schema else {
            XCTFail("Expected object value")
            return
        }
        XCTAssertEqual(dict["type"], .string("object"))
        XCTAssertNil(dict["properties"])
        XCTAssertNil(dict["required"])
    }

    func testSchemaWithProperties() {
        let schema = jsonSchema(
            type: "object",
            properties: [
                "name": ["type": "string", "description": "A name"]
            ]
        )
        guard case .object(let dict) = schema,
              case .object(let props) = dict["properties"],
              case .object(let nameProp) = props["name"] else {
            XCTFail("Expected nested object structure")
            return
        }
        XCTAssertEqual(nameProp["type"], .string("string"))
        XCTAssertEqual(nameProp["description"], .string("A name"))
    }

    func testSchemaWithRequired() {
        let schema = jsonSchema(
            type: "object",
            properties: ["x": ["type": "integer"]],
            required: ["x"]
        )
        guard case .object(let dict) = schema,
              case .array(let req) = dict["required"] else {
            XCTFail("Expected required array")
            return
        }
        XCTAssertEqual(req, [.string("x")])
    }

    func testSchemaWithAllValueTypes() {
        let schema = jsonSchema(
            type: "object",
            properties: [
                "str": ["type": "string", "default": "hello"],
                "num": ["type": "integer", "default": 42],
                "dbl": ["type": "number", "default": 3.14],
                "flag": ["type": "boolean", "default": true]
            ]
        )
        guard case .object(let dict) = schema,
              case .object(let props) = dict["properties"] else {
            XCTFail("Expected properties")
            return
        }

        // Check string property
        if case .object(let strProp) = props["str"] {
            XCTAssertEqual(strProp["default"], .string("hello"))
        } else { XCTFail("Missing str property") }

        // Check int property
        if case .object(let numProp) = props["num"] {
            XCTAssertEqual(numProp["default"], .int(42))
        } else { XCTFail("Missing num property") }

        // Check double property
        if case .object(let dblProp) = props["dbl"] {
            XCTAssertEqual(dblProp["default"], .double(3.14))
        } else { XCTFail("Missing dbl property") }

        // Check bool property
        if case .object(let flagProp) = props["flag"] {
            XCTAssertEqual(flagProp["default"], .bool(true))
        } else { XCTFail("Missing flag property") }
    }
}
