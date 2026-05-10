// STORY-007 — click_menu_item MCP Tool
// COMPONENT: MenuItemNormalizer

import XCTest
@testable import MacOSControlLib

final class MenuItemNormalizerTests: XCTestCase {

    var normalizer: MenuItemNormalizer!

    override func setUp() {
        super.setUp()
        normalizer = MenuItemNormalizer()
    }

    func test_normalize_stripsTrailingAsciiEllipsis() {
        XCTAssertEqual(normalizer.normalize("Save..."), "Save")
        XCTAssertEqual(normalizer.normalize("Save As..."), "Save As")
    }

    func test_normalize_stripsTrailingUnicodeEllipsis() {
        XCTAssertEqual(normalizer.normalize("Save\u{2026}"), "Save")
    }

    func test_normalize_trimsWhitespace() {
        XCTAssertEqual(normalizer.normalize("  Save  "), "Save")
        XCTAssertEqual(normalizer.normalize("\tSave\n"), "Save")
    }

    func test_normalize_handlesCombination() {
        XCTAssertEqual(normalizer.normalize("  Save\u{2026}  "), "Save")
        XCTAssertEqual(normalizer.normalize("  Save...  "), "Save")
    }

    func test_normalize_isIdempotent() {
        let once  = normalizer.normalize("Save...")
        let twice = normalizer.normalize(once)
        XCTAssertEqual(once, twice)
    }

    func test_normalize_doesNotStripInternalEllipsis() {
        XCTAssertEqual(normalizer.normalize("Save... and Continue"),
                       "Save... and Continue")
    }

    func test_normalize_doesNotAttemptToStripAccelerators() {
        // Accelerators don't appear in AppleScript-visible names; the normalizer
        // should leave them untouched if they ever appear in input.
        XCTAssertEqual(normalizer.normalize("Save  ⌘S"), "Save  ⌘S")
    }
}
