// STORY: STORY-009 — Element State Polling Tool
// COMPONENT: ConditionExpressionParser (parses "field = value" expressions)

import XCTest
@testable import MacOSControlLib

final class ConditionExpressionParserTests: XCTestCase {

    var parser: ConditionExpressionParser!

    override func setUp() {
        super.setUp()
        parser = ConditionExpressionParser()
    }

    // MARK: - Happy Path

    func test_parse_acceptsBooleanFields() throws {
        let cases: [(String, ConditionField, ConditionLiteral)] = [
            ("enabled = true",             .enabled,            .bool(true)),
            ("exists = false",             .exists,             .bool(false)),
            ("focused = true",             .focused,            .bool(true)),
            ("selected = true",            .selected,           .bool(true)),
            ("expanded = false",           .expanded,           .bool(false)),
            ("visible_in_viewport = true", .visibleInViewport,  .bool(true)),
            ("is_main = true",             .isMain,             .bool(true)),
            ("is_minimized = false",       .isMinimized,        .bool(false)),
            ("is_frontmost = true",        .isFrontmost,        .bool(true)),
        ]
        for (input, expectedField, expectedLiteral) in cases {
            let parsed = try parser.parse(input)
            XCTAssertEqual(parsed.field, expectedField, input)
            XCTAssertEqual(parsed.literal, expectedLiteral, input)
            XCTAssertEqual(parsed.op, .equals, input)
        }
    }

    func test_parse_acceptsValueStringEquality_singleAndDoubleQuotes() throws {
        let single = try parser.parse("value = 'Connected'")
        XCTAssertEqual(single.field, .value)
        XCTAssertEqual(single.literal, .string("Connected"))

        let double = try parser.parse("value = \"Connected\"")
        XCTAssertEqual(double.literal, .string("Connected"))
    }

    func test_parse_valueLiteralMayContainEquals() throws {
        let parsed = try parser.parse("value = 'a=b'")
        XCTAssertEqual(parsed.literal, .string("a=b"))
    }

    func test_parse_isCaseInsensitiveForBooleanLiteralsOnly() throws {
        XCTAssertEqual(try parser.parse("enabled = TRUE").literal, .bool(true))
        // value comparison stays case-sensitive — the literal is preserved verbatim.
        XCTAssertEqual(try parser.parse("value = 'Connected'").literal, .string("Connected"))
        XCTAssertNotEqual(try parser.parse("value = 'connected'").literal, .string("Connected"))
    }

    func test_parse_toleratesSurroundingWhitespace() throws {
        let parsed = try parser.parse("   focused   =   true   ")
        XCTAssertEqual(parsed.field, .focused)
        XCTAssertEqual(parsed.literal, .bool(true))
    }

    // MARK: - Error Paths

    func test_parse_rejectsDoubleEqualsChain() {
        XCTAssertThrowsError(try parser.parse("selected = banana = true")) { error in
            guard let err = error as? InvalidConditionExpressionError else {
                XCTFail("Expected InvalidConditionExpressionError"); return
            }
            XCTAssertTrue(err.supportedFields.contains("enabled"))
            XCTAssertTrue(err.supportedOperators.contains("="))
        }
    }

    func test_parse_rejectsUnknownField() {
        XCTAssertThrowsError(try parser.parse("magical = true")) { error in
            XCTAssertTrue(error is InvalidConditionExpressionError)
        }
    }

    func test_parse_rejectsEmptyExpression() {
        XCTAssertThrowsError(try parser.parse(""))
        XCTAssertThrowsError(try parser.parse("   "))
    }

    func test_parse_rejectsMissingOperator() {
        XCTAssertThrowsError(try parser.parse("enabled true"))
    }

    func test_parse_rejectsMissingFieldOrValue() {
        XCTAssertThrowsError(try parser.parse("= true"))
        XCTAssertThrowsError(try parser.parse("enabled ="))
    }

    func test_parse_rejectsTypeMismatch_stringForBooleanField() {
        XCTAssertThrowsError(try parser.parse("enabled = 'true'")) { error in
            XCTAssertTrue(error is InvalidConditionExpressionError)
        }
    }

    func test_parse_rejectsTypeMismatch_barewordForValueField() {
        XCTAssertThrowsError(try parser.parse("value = Connected")) { error in
            XCTAssertTrue(error is InvalidConditionExpressionError)
        }
    }

    func test_parse_rejectsNonBooleanBareword() {
        XCTAssertThrowsError(try parser.parse("enabled = banana"))
    }

    func test_error_exposesLocalizedDescription() {
        XCTAssertThrowsError(try parser.parse("nope = true")) { error in
            guard let err = error as? InvalidConditionExpressionError else {
                XCTFail("wrong error type"); return
            }
            XCTAssertEqual(err.errorDescription, err.description)
            XCTAssertTrue(err.description.contains("invalid_condition_expression"))
        }
    }

    func test_error_listsSupportedFieldsAndOperators() {
        XCTAssertThrowsError(try parser.parse("nope = true")) { error in
            guard let err = error as? InvalidConditionExpressionError else {
                XCTFail("wrong error type"); return
            }
            XCTAssertEqual(Set(err.supportedFields), Set(ConditionField.allNames))
            XCTAssertEqual(err.supportedOperators, ["="])
            // The structured result advertises the same vocabulary.
            let result = err.toStructuredResult()
            XCTAssertEqual(result.isError, true)
        }
    }
}
