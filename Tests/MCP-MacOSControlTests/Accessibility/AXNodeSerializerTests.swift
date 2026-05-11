// STORY: STORY-004 — Enhanced Accessibility Tree Tool
// COMPONENT: AXNodeSerializer

import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class AXNodeSerializerTests: XCTestCase {

    var serializer: AXNodeSerializer!

    override func setUp() {
        super.setUp()
        serializer = AXNodeSerializer()
    }

    // MARK: - Enabled Flag (Scenario 2)

    func test_serialize_enabledFalse_whenAXEnabledIsFalse() {
        let node = AXNode(role: "AXMenuItem", title: "Cut", enabled: false)
        let json = serializer.serialize(node)
        XCTAssertEqual(json["enabled"] as? Bool, false)
    }

    func test_serialize_enabledTrue_whenAXEnabledIsTrue() {
        let node = AXNode(role: "AXMenuItem", title: "Copy", enabled: true)
        let json = serializer.serialize(node)
        XCTAssertEqual(json["enabled"] as? Bool, true)
    }

    func test_serialize_omitsEnabledField_whenAttributeUnsupported() {
        let node = AXNode(role: "AXGroup", enabled: nil)
        let json = serializer.serialize(node)
        XCTAssertNil(json["enabled"])
    }

    // MARK: - Identifier (Scenario 3)

    func test_serialize_includesIdentifier_whenAXIdentifierIsNonNil() {
        let node = AXNode(role: "AXButton", title: "Save", identifier: "com.app.save-button")
        let json = serializer.serialize(node)
        XCTAssertEqual(json["identifier"] as? String, "com.app.save-button")
    }

    func test_serialize_omitsIdentifier_whenAXIdentifierIsNil() {
        let node = AXNode(role: "AXButton", title: "Save", identifier: nil)
        let json = serializer.serialize(node)
        XCTAssertNil(json["identifier"])
    }

    func test_serialize_omitsIdentifier_whenAXIdentifierIsEmptyString() {
        let node = AXNode(role: "AXButton", title: "Save", identifier: "")
        let json = serializer.serialize(node)
        XCTAssertNil(json["identifier"])
    }

    // MARK: - Settable Flag (Scenario 4)

    func test_serialize_settableTrue_forAXTextField_whenValueSettable() {
        let node = AXNode(role: "AXTextField", title: "Username", settable: true)
        let json = serializer.serialize(node)
        XCTAssertEqual(json["settable"] as? Bool, true)
    }

    func test_serialize_settableTrue_forAXSlider() {
        let node = AXNode(role: "AXSlider", title: "Volume", settable: true)
        let json = serializer.serialize(node)
        XCTAssertEqual(json["settable"] as? Bool, true)
    }

    func test_serialize_settableFalse_forAXStaticText() {
        let node = AXNode(role: "AXStaticText", title: "Version", settable: false)
        let json = serializer.serialize(node)
        XCTAssertEqual(json["settable"] as? Bool, false)
    }

    func test_serialize_omitsSettableField_whenNil() {
        let node = AXNode(role: "AXGroup", settable: nil)
        let json = serializer.serialize(node)
        XCTAssertNil(json["settable"])
    }

    // MARK: - Backward Compatibility (Scenario 6)

    func test_serialize_includesAllPreExistingFields() {
        let node = AXNode(
            role: "AXButton",
            title: "Bold",
            value: nil,
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 40, height: 40)
        )

        let json = serializer.serialize(node)

        XCTAssertEqual(json["role"] as? String, "AXButton")
        XCTAssertEqual(json["title"] as? String, "Bold")
        XCTAssertNotNil(json["position"])
        XCTAssertNotNil(json["size"])

        let position = json["position"] as? [String: Int]
        XCTAssertEqual(position?["x"], 100)
        XCTAssertEqual(position?["y"], 200)

        let size = json["size"] as? [String: Int]
        XCTAssertEqual(size?["width"], 40)
        XCTAssertEqual(size?["height"], 40)
    }

    func test_serialize_includesDescription_whenPresent() {
        let node = AXNode(role: "AXButton", description: "Save the document")
        let json = serializer.serialize(node)
        XCTAssertEqual(json["description"] as? String, "Save the document")
    }

    func test_serialize_includesStringValue_asString() {
        let node = AXNode(role: "AXTextField", value: .string("hello"))
        let json = serializer.serialize(node)
        XCTAssertEqual(json["value"] as? String, "hello")
    }

    func test_serialize_includesNumericValue_asNumber() {
        let node = AXNode(role: "AXSlider", value: .number(NSNumber(value: 0.42)))
        let json = serializer.serialize(node)
        XCTAssertEqual(json["value"] as? NSNumber, NSNumber(value: 0.42))
    }

    func test_serializeRoot_includesSchemaVersion3_atTopLevel() {
        let node = AXNode(role: "AXApplication")
        let response = serializer.serializeRoot(node)
        XCTAssertEqual(response["schema_version"] as? Int, 3)
    }

    func test_serializeRoot_keepsRootFieldsAtTopLevel_forBackwardCompatibility() {
        // Pre-existing callers read response["role"], response["title"] directly.
        // schema_version must be a sibling key, not a wrapping envelope.
        let node = AXNode(role: "AXApplication", title: "TextEdit")
        let response = serializer.serializeRoot(node)
        XCTAssertEqual(response["role"] as? String, "AXApplication")
        XCTAssertEqual(response["title"] as? String, "TextEdit")
    }

    // MARK: - Action Names

    func test_serialize_includesActionsList_whenPresent() {
        let node = AXNode(role: "AXButton", title: "Bold", actions: ["AXPress"])
        let json = serializer.serialize(node)
        XCTAssertEqual(json["actions"] as? [String], ["AXPress"])
    }

    func test_serialize_omitsActionsList_whenEmpty() {
        let node = AXNode(role: "AXStaticText", title: "Version", actions: [])
        let json = serializer.serialize(node)
        XCTAssertNil(json["actions"], "empty actions array should be omitted, not emitted as []")
    }

    // MARK: - Truncated Flag

    func test_serialize_includesTruncated_whenSet() {
        let node = AXNode(role: "AXScrollArea", truncated: true)
        let json = serializer.serialize(node)
        XCTAssertEqual(json["truncated"] as? Bool, true)
    }

    func test_serialize_omitsTruncated_whenNil() {
        let node = AXNode(role: "AXScrollArea", truncated: nil)
        let json = serializer.serialize(node)
        XCTAssertNil(json["truncated"])
    }

    // MARK: - Children & childCount

    func test_serialize_recursesIntoChildren() {
        let leaf = AXNode(role: "AXButton", title: "OK")
        let parent = AXNode(role: "AXGroup", children: [leaf])
        let json = serializer.serialize(parent)
        let kids = json["children"] as? [[String: Any]]
        XCTAssertEqual(kids?.count, 1)
        XCTAssertEqual(kids?.first?["role"] as? String, "AXButton")
        XCTAssertEqual(kids?.first?["title"] as? String, "OK")
    }

    func test_serialize_emitsChildCount_whenChildrenPrunedAndCountKnown() {
        // When children were pruned by depth budget, surface childCount as the existing
        // schema does — preserves backward compat with the v1 reader.
        let parent = AXNode(role: "AXScrollArea", truncated: true, children: [], prunedChildCount: 7)
        let json = serializer.serialize(parent)
        XCTAssertEqual(json["childCount"] as? Int, 7)
    }
}
