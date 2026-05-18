import Foundation
import MCP

/// STORY-009 — the closed set of element-state fields that
/// `wait_for_element_state` can predicate on. Every entry except `.exists`
/// (synthetic — derived from whether the element resolved at all) maps onto a
/// field the STORY-015 `AXNodeSerializer` emits.
public enum ConditionField: String, CaseIterable, Sendable {
    case enabled
    case exists
    case focused
    case selected
    case expanded
    case visibleInViewport = "visible_in_viewport"
    case isMain = "is_main"
    case isMinimized = "is_minimized"
    case isFrontmost = "is_frontmost"
    case value

    /// `value` is the only field whose literal is a string; everything else is
    /// a boolean predicate.
    var expectsStringLiteral: Bool { self == .value }

    /// Token list surfaced in `invalid_condition_expression` errors.
    public static var allNames: [String] { allCases.map(\.rawValue) }
}

/// Operator vocabulary. Only `=` is accepted at v1; the enum exists so a future
/// `!=` / `~=` can be added without reworking the parser's structure.
public enum ConditionOperator: String, CaseIterable, Sendable {
    case equals = "="

    public static var allSymbols: [String] { allCases.map(\.rawValue) }
}

public enum ConditionLiteral: Equatable, Sendable {
    case bool(Bool)
    case string(String)
}

public struct ParsedCondition: Equatable, Sendable {
    public let field: ConditionField
    public let op: ConditionOperator
    public let literal: ConditionLiteral

    public init(field: ConditionField, op: ConditionOperator, literal: ConditionLiteral) {
        self.field = field
        self.op = op
        self.literal = literal
    }
}

/// Thrown when a `condition` string cannot be parsed. Carries the supported
/// vocabulary so the agent can self-correct from the error alone.
public struct InvalidConditionExpressionError: Error, CustomStringConvertible, LocalizedError {
    public let expression: String
    public let reason: String
    public let supportedFields: [String]
    public let supportedOperators: [String]
    public let errorCode: String = "invalid_condition_expression"

    public init(
        expression: String,
        reason: String,
        supportedFields: [String] = ConditionField.allNames,
        supportedOperators: [String] = ConditionOperator.allSymbols
    ) {
        self.expression = expression
        self.reason = reason
        self.supportedFields = supportedFields
        self.supportedOperators = supportedOperators
    }

    public var description: String {
        "\(errorCode): \(reason) — expression \"\(expression)\""
    }
    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: description,
            details: [
                "expression": expression,
                "supported_fields": supportedFields,
                "supported_operators": supportedOperators
            ]
        )
    }
}

/// Parses a `field = value` condition expression into a `ParsedCondition`.
///
/// Grammar (v1):
///
///     condition := field "=" literal
///     field     := one of ConditionField.allNames
///     literal   := "true" | "false"          (boolean fields)
///                | "'" ... "'" | "\"" ... "\"" (the `value` field)
public final class ConditionExpressionParser {

    public init() {}

    public func parse(_ raw: String) throws -> ParsedCondition {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw InvalidConditionExpressionError(
                expression: raw,
                reason: "expression is empty"
            )
        }

        guard let eqIndex = trimmed.firstIndex(of: "=") else {
            throw InvalidConditionExpressionError(
                expression: raw,
                reason: "expected a '<field> = <value>' expression"
            )
        }

        let fieldToken = String(trimmed[trimmed.startIndex..<eqIndex])
            .trimmingCharacters(in: .whitespaces)
        let rhs = String(trimmed[trimmed.index(after: eqIndex)...])
            .trimmingCharacters(in: .whitespaces)

        guard !fieldToken.isEmpty else {
            throw InvalidConditionExpressionError(
                expression: raw,
                reason: "missing field name before '='"
            )
        }
        guard let field = ConditionField(rawValue: fieldToken) else {
            throw InvalidConditionExpressionError(
                expression: raw,
                reason: "unknown field '\(fieldToken)'"
            )
        }
        guard !rhs.isEmpty else {
            throw InvalidConditionExpressionError(
                expression: raw,
                reason: "missing value after '='"
            )
        }

        let literal = try parseLiteral(rhs, field: field, raw: raw)
        return ParsedCondition(field: field, op: .equals, literal: literal)
    }

    private func parseLiteral(
        _ rhs: String,
        field: ConditionField,
        raw: String
    ) throws -> ConditionLiteral {
        if let quoted = unquote(rhs) {
            guard field.expectsStringLiteral else {
                throw InvalidConditionExpressionError(
                    expression: raw,
                    reason: "field '\(field.rawValue)' expects a boolean (true/false), not a quoted string"
                )
            }
            return .string(quoted)
        }

        // Unquoted right-hand side. A second '=' here is the double-equals
        // chain ("selected = banana = true") — reject it explicitly.
        if rhs.contains("=") {
            throw InvalidConditionExpressionError(
                expression: raw,
                reason: "unexpected second '=' — only one operator is allowed"
            )
        }

        if field.expectsStringLiteral {
            throw InvalidConditionExpressionError(
                expression: raw,
                reason: "field 'value' expects a quoted string literal, e.g. value = 'Connected'"
            )
        }

        switch rhs.lowercased() {
        case "true": return .bool(true)
        case "false": return .bool(false)
        default:
            throw InvalidConditionExpressionError(
                expression: raw,
                reason: "field '\(field.rawValue)' expects true or false, got '\(rhs)'"
            )
        }
    }

    /// Returns the inner content when `s` is wrapped in a matching pair of
    /// single or double quotes; otherwise nil. Quotes may contain `=`.
    private func unquote(_ s: String) -> String? {
        guard s.count >= 2, let first = s.first, let last = s.last else { return nil }
        guard (first == "'" && last == "'") || (first == "\"" && last == "\"") else {
            return nil
        }
        return String(s.dropFirst().dropLast())
    }
}
