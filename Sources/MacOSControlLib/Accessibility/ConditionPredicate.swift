import Foundation

/// STORY-009 — evaluates a `ParsedCondition` against one `ElementProbeResult`.
///
/// Semantics:
///  * `exists`: matched ⇒ true, notFound ⇒ false (compared to the literal).
///  * other boolean fields: only meaningful when the element resolved; a `nil`
///    serialized property means "not in that state yet" (false), so the poll
///    loop keeps waiting rather than treating absence as a match.
///  * `value`: exact, case-sensitive string comparison; numeric values are
///    stringified (Q4 — string comparison only at v1).
public final class ConditionPredicate {

    private let condition: ParsedCondition

    public init(_ condition: ParsedCondition) {
        self.condition = condition
    }

    public func evaluate(_ result: ElementProbeResult) -> Bool {
        switch condition.field {
        case .exists:
            guard case .bool(let want) = condition.literal else { return false }
            let actual: Bool = {
                if case .matched = result { return true }
                return false
            }()
            return actual == want

        case .value:
            guard case .matched(let node) = result,
                  case .string(let want) = condition.literal,
                  let value = node.value else { return false }
            return stringify(value) == want

        case .enabled, .focused, .selected, .expanded,
             .visibleInViewport, .isMain, .isMinimized, .isFrontmost:
            guard case .matched(let node) = result,
                  case .bool(let want) = condition.literal,
                  let actual = booleanField(condition.field, of: node) else { return false }
            return actual == want
        }
    }

    private func booleanField(_ field: ConditionField, of node: AXNode) -> Bool? {
        switch field {
        case .enabled:            return node.enabled
        case .focused:            return node.focused
        case .selected:           return node.selected
        case .expanded:           return node.expanded
        case .visibleInViewport:  return node.visibleInViewport
        case .isMain:             return node.isMain
        case .isMinimized:        return node.isMinimized
        case .isFrontmost:        return node.isFrontmost
        case .exists, .value:     return nil
        }
    }

    private func stringify(_ value: AXNodeValue) -> String {
        switch value {
        case .string(let s): return s
        case .number(let n): return n.stringValue
        }
    }
}
