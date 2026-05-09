import Foundation

public enum AXElementValidator {
    public static func validate(
        _ ref: AXElementReference,
        expects: [AXAttributeKind: String]
    ) throws {
        for (kind, expected) in expects {
            let actual = readAttribute(kind, from: ref)
            guard let actual = actual else {
                throw AXResolutionError(
                    detail: "Element missing expected attribute '\(kind.rawValue)'"
                )
            }
            guard actual == expected else {
                throw AXResolutionError(
                    detail: "Element attribute '\(kind.rawValue)' was '\(actual)', expected '\(expected)'"
                )
            }
        }
    }

    private static func readAttribute(_ kind: AXAttributeKind, from ref: AXElementReference) -> String? {
        switch kind {
        case .role: return ref.role
        case .title: return ref.title
        case .identifier: return ref.identifier
        case .label: return ref.label
        case .description: return ref.description
        }
    }
}
