import Foundation

/// Parsed query parameters for the `find_elements` tool. All fields are optional;
/// at least one of role / title* / identifier* / label / description must be set
/// or `ElementPredicate.compile(...)` throws `.predicateTooBroad`.
public struct FindElementsInput {
    public var role: String?
    public var title: String?
    public var titleContains: String?
    public var titleMatches: String?
    public var identifier: String?
    public var identifierMatches: String?
    public var label: String?
    public var elementDescription: String?

    public init(
        role: String? = nil,
        title: String? = nil,
        titleContains: String? = nil,
        titleMatches: String? = nil,
        identifier: String? = nil,
        identifierMatches: String? = nil,
        label: String? = nil,
        description: String? = nil
    ) {
        self.role = role
        self.title = title
        self.titleContains = titleContains
        self.titleMatches = titleMatches
        self.identifier = identifier
        self.identifierMatches = identifierMatches
        self.label = label
        self.elementDescription = description
    }
}

public enum FindElementsError: Error, Equatable {
    case predicateTooBroad
    case conflictingTitlePredicates
    case conflictingIdentifierPredicates
    case invalidRegex(field: String, message: String)

    public var code: String {
        switch self {
        case .predicateTooBroad:                return "predicate_too_broad"
        case .conflictingTitlePredicates:       return "conflicting_title_predicates"
        case .conflictingIdentifierPredicates:  return "conflicting_identifier_predicates"
        case .invalidRegex:                     return "invalid_regex"
        }
    }

    public var message: String {
        switch self {
        case .predicateTooBroad:
            return "find_elements requires at least one of: role, title, title_contains, title_matches, identifier, identifier_matches, label, description"
        case .conflictingTitlePredicates:
            return "at most one of title, title_contains, title_matches may be set per call"
        case .conflictingIdentifierPredicates:
            return "at most one of identifier, identifier_matches may be set per call"
        case .invalidRegex(let field, let message):
            return "field '\(field)' contains an invalid regex: \(message)"
        }
    }
}

/// Compiled query matcher. Operates on `AXElementReference` so the walker pays
/// only the lightweight reference cost per visited node — full attribute
/// extraction (`AccessibilityTreeBuilder.buildShallow`) happens only for
/// matches.
public final class ElementPredicate {

    private let role: String?
    private let title: String?
    private let titleContains: String?
    private let titleMatchesRegex: NSRegularExpression?
    private let identifier: String?
    private let identifierMatchesRegex: NSRegularExpression?
    private let label: String?
    private let elementDescription: String?

    private init(
        role: String?,
        title: String?,
        titleContains: String?,
        titleMatchesRegex: NSRegularExpression?,
        identifier: String?,
        identifierMatchesRegex: NSRegularExpression?,
        label: String?,
        elementDescription: String?
    ) {
        self.role = role
        self.title = title
        self.titleContains = titleContains
        self.titleMatchesRegex = titleMatchesRegex
        self.identifier = identifier
        self.identifierMatchesRegex = identifierMatchesRegex
        self.label = label
        self.elementDescription = elementDescription
    }

    public static func compile(from input: FindElementsInput) throws -> ElementPredicate {
        let titleFieldsSet = [input.title, input.titleContains, input.titleMatches]
            .filter { $0 != nil }.count
        if titleFieldsSet > 1 {
            throw FindElementsError.conflictingTitlePredicates
        }

        let identifierFieldsSet = [input.identifier, input.identifierMatches]
            .filter { $0 != nil }.count
        if identifierFieldsSet > 1 {
            throw FindElementsError.conflictingIdentifierPredicates
        }

        let anyCriterionSet = input.role != nil
            || input.title != nil
            || input.titleContains != nil
            || input.titleMatches != nil
            || input.identifier != nil
            || input.identifierMatches != nil
            || input.label != nil
            || input.elementDescription != nil
        guard anyCriterionSet else {
            throw FindElementsError.predicateTooBroad
        }

        let titleRegex = try compileRegex(input.titleMatches, field: "title_matches")
        let identifierRegex = try compileRegex(input.identifierMatches, field: "identifier_matches")

        return ElementPredicate(
            role: input.role,
            title: input.title,
            titleContains: input.titleContains,
            titleMatchesRegex: titleRegex,
            identifier: input.identifier,
            identifierMatchesRegex: identifierRegex,
            label: input.label,
            elementDescription: input.elementDescription
        )
    }

    public func matches(_ ref: AXElementReference) -> Bool {
        if let role, ref.role != role { return false }

        if let title, ref.title != title { return false }
        if let titleContains {
            guard let actualTitle = ref.title,
                  actualTitle.localizedCaseInsensitiveContains(titleContains) else {
                return false
            }
        }
        if let titleMatchesRegex {
            guard let actualTitle = ref.title, Self.regexMatches(titleMatchesRegex, actualTitle) else {
                return false
            }
        }

        if let identifier, ref.identifier != identifier { return false }
        if let identifierMatchesRegex {
            guard let actualId = ref.identifier, Self.regexMatches(identifierMatchesRegex, actualId) else {
                return false
            }
        }

        if let label, ref.label != label { return false }
        if let elementDescription, ref.description != elementDescription { return false }

        return true
    }

    private static func compileRegex(_ pattern: String?, field: String) throws -> NSRegularExpression? {
        guard let pattern else { return nil }
        do {
            return try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            throw FindElementsError.invalidRegex(
                field: field,
                message: (error as NSError).localizedDescription
            )
        }
    }

    private static func regexMatches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
