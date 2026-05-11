// STORY: STORY-015 — Extended Element State Attributes
// COMPONENT: ViewportVisibilityResolver

import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class ViewportVisibilityResolverTests: XCTestCase {

    var resolver: ViewportVisibilityResolver!

    override func setUp() {
        super.setUp()
        resolver = ViewportVisibilityResolver()
    }

    // MARK: - Visibility Boundaries (Scenario 4)

    func test_isVisible_returnsTrue_whenNodeFrameWithinWindow() {
        let node   = CGRect(x: 100, y: 100, width: 50, height: 30)
        let window = CGRect(x: 0,   y: 0,   width: 800, height: 600)
        XCTAssertEqual(resolver.isVisible(nodeFrame: node, in: window), true)
    }

    func test_isVisible_returnsFalse_whenNodeFrameOutsideWindow() {
        let node   = CGRect(x: 1000, y: 1000, width: 50, height: 30)
        let window = CGRect(x: 0,    y: 0,    width: 800, height: 600)
        XCTAssertEqual(resolver.isVisible(nodeFrame: node, in: window), false)
    }

    func test_isVisible_returnsTrue_forPartialClip() {
        // Node straddles the window's right edge — half visible, half clipped
        let node   = CGRect(x: 750, y: 100, width: 100, height: 30)
        let window = CGRect(x: 0,   y: 0,   width: 800, height: 600)
        XCTAssertEqual(resolver.isVisible(nodeFrame: node, in: window), true,
                       "Any pixel intersection counts as visible (Open Q2 resolution)")
    }

    func test_isVisible_returnsFalse_forZeroSizedNode() {
        let node   = CGRect(x: 100, y: 100, width: 0, height: 0)
        let window = CGRect(x: 0,   y: 0,   width: 800, height: 600)
        XCTAssertEqual(resolver.isVisible(nodeFrame: node, in: window), false)
    }

    // MARK: - Absent Containing Window

    func test_isVisible_returnsNil_whenContainingWindowFrameUnavailable() {
        let node = CGRect(x: 100, y: 100, width: 50, height: 30)
        XCTAssertNil(resolver.isVisible(nodeFrame: node, in: nil),
                     "nil window frame must produce nil result, not false — caller omits the field")
    }

    func test_isVisible_returnsNil_whenNodeFrameUnavailable() {
        let window = CGRect(x: 0, y: 0, width: 800, height: 600)
        XCTAssertNil(resolver.isVisible(nodeFrame: nil, in: window))
    }
}
