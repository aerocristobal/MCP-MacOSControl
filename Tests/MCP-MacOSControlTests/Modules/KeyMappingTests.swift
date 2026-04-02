import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class KeyMappingTests: XCTestCase {

    // MARK: - Letter Keys

    func testLetterKeyA() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "a"), 0x00)
    }

    func testLetterKeyZ() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "z"), 0x06)
    }

    func testLetterKeyM() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "m"), 0x2E)
    }

    // MARK: - Special Keys

    func testReturnKey() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "return"), 0x24)
    }

    func testEscapeKey() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "escape"), 0x35)
    }

    func testTabKey() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "tab"), 0x30)
    }

    func testSpaceKey() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "space"), 0x31)
    }

    func testDeleteKey() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "delete"), 0x33)
    }

    // MARK: - Arrow Keys

    func testUpArrow() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "up"), 0x7E)
    }

    func testDownArrow() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "down"), 0x7D)
    }

    func testLeftArrow() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "left"), 0x7B)
    }

    func testRightArrow() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "right"), 0x7C)
    }

    // MARK: - Modifier Keys

    func testCommandModifier() {
        XCTAssertEqual(KeyboardControl.getModifierFlag(for: "cmd"), .maskCommand)
    }

    func testShiftModifier() {
        XCTAssertEqual(KeyboardControl.getModifierFlag(for: "shift"), .maskShift)
    }

    func testControlModifier() {
        XCTAssertEqual(KeyboardControl.getModifierFlag(for: "ctrl"), .maskControl)
    }

    func testAlternateModifier() {
        XCTAssertEqual(KeyboardControl.getModifierFlag(for: "alt"), .maskAlternate)
    }

    // MARK: - Aliases

    func testCommandAlias() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "cmd"), KeyboardControl.getKeyCode(for: "command"))
    }

    func testEscapeAlias() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "esc"), KeyboardControl.getKeyCode(for: "escape"))
    }

    func testControlAlias() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "ctrl"), KeyboardControl.getKeyCode(for: "control"))
    }

    func testAlternateAlias() {
        XCTAssertEqual(KeyboardControl.getKeyCode(for: "alt"), KeyboardControl.getKeyCode(for: "option"))
    }

    // MARK: - Unknown Key

    func testUnknownKeyReturnsNil() {
        XCTAssertNil(KeyboardControl.getKeyCode(for: "nonexistent_key_xyz"))
    }

    func testUnknownModifierReturnsNil() {
        XCTAssertNil(KeyboardControl.getModifierFlag(for: "nonexistent"))
    }
}
