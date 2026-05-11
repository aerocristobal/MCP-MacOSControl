// STORY-014 — Find Elements by Query
// COMPONENT: AXPathBuilder

import XCTest
@testable import MacOSControlLib

final class AXPathBuilderTests: XCTestCase {

    private func ref(role: String?, title: String? = nil, identifier: String? = nil) -> AXElementReference {
        AXElementReference(
            role: role,
            title: title,
            identifier: identifier,
            handle: .mock(UUID())
        )
    }

    // MARK: - Path Format (Scenario 3)

    func test_path_startsWithApplicationRole_andTitle() {
        let app = ref(role: "AXApplication", title: "TextEdit")
        let window = ref(role: "AXWindow", title: "Untitled")
        let button = ref(role: "AXButton", title: "Close")

        let path = AXPathBuilder.path(ancestors: [app, window], target: button)

        XCTAssertEqual(path, [
            "AXApplication[TextEdit]",
            "AXWindow[Untitled]",
            "AXButton[Close]"
        ])
    }

    func test_path_usesIdentifier_whenTitleAbsent() {
        let group = ref(role: "AXGroup", identifier: "main-content")
        let button = ref(role: "AXButton", title: "OK")

        let path = AXPathBuilder.path(ancestors: [group], target: button)

        XCTAssertEqual(path, ["AXGroup[main-content]", "AXButton[OK]"])
    }

    func test_path_prefersTitle_overIdentifier_whenBothPresent() {
        let group = ref(role: "AXGroup", title: "Toolbar", identifier: "main-toolbar")
        let button = ref(role: "AXButton", title: "Save")

        let path = AXPathBuilder.path(ancestors: [group], target: button)

        XCTAssertEqual(path, ["AXGroup[Toolbar]", "AXButton[Save]"])
    }

    func test_path_emitsEmptyDisambiguator_whenBothTitleAndIdentifierAbsent() {
        let group = ref(role: "AXSplitGroup")
        let button = ref(role: "AXButton", title: "Save")

        let path = AXPathBuilder.path(ancestors: [group], target: button)

        XCTAssertEqual(path, ["AXSplitGroup[]", "AXButton[Save]"])
    }

    func test_path_singleElement_whenNoAncestors() {
        let target = ref(role: "AXApplication", title: "Finder")

        let path = AXPathBuilder.path(ancestors: [], target: target)

        XCTAssertEqual(path, ["AXApplication[Finder]"])
    }

    func test_path_treatsMissingRoleAsAXUnknown() {
        let mystery = ref(role: nil, title: "Mystery")
        let button = ref(role: "AXButton", title: "OK")

        let path = AXPathBuilder.path(ancestors: [mystery], target: button)

        XCTAssertEqual(path, ["AXUnknown[Mystery]", "AXButton[OK]"])
    }
}
