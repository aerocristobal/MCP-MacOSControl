// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: ResourceURIParser

import XCTest
@testable import MacOSControlLib

final class ResourceURITests: XCTestCase {

    func test_parse_extractsCanonicalURI_withoutQuery() {
        let parsed = ResourceURIParser.parse("macos://ui/active-window-tree")
        XCTAssertEqual(parsed.canonicalURI, "macos://ui/active-window-tree")
        XCTAssertTrue(parsed.queryItems.isEmpty)
    }

    func test_parse_extractsMaxDepthQueryItem() {
        let parsed = ResourceURIParser.parse("macos://ui/active-window-tree?max_depth=12")
        XCTAssertEqual(parsed.canonicalURI, "macos://ui/active-window-tree")
        XCTAssertEqual(parsed.queryItems["max_depth"], "12")
        XCTAssertEqual(parsed.maxDepth(), 12)
    }

    func test_maxDepth_returnsDefault_whenQueryAbsent() {
        let parsed = ResourceURIParser.parse(ResourceURIs.activeWindowTree)
        XCTAssertEqual(parsed.maxDepth(), 6)
    }

    func test_maxDepth_returnsDefault_whenValueNotAnInteger() {
        let parsed = ResourceURIParser.parse("macos://ui/active-window-tree?max_depth=abc")
        XCTAssertEqual(parsed.maxDepth(), 6)
    }

    func test_maxDepth_clampsBelowLowerBound() {
        let parsed = ResourceURIParser.parse("macos://ui/active-window-tree?max_depth=0")
        XCTAssertEqual(parsed.maxDepth(), 1)
    }

    func test_maxDepth_clampsAboveUpperBound() {
        let parsed = ResourceURIParser.parse("macos://ui/active-window-tree?max_depth=999")
        XCTAssertEqual(parsed.maxDepth(), 50)
    }
}
