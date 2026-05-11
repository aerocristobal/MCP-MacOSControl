import Foundation

/// Formats an AX ancestor chain into the string-array `ax_path` shape used by
/// `find_elements` responses. Each component is `"<AXRole>[<disambiguator>]"`
/// where the disambiguator is the element's title if non-empty, else its
/// identifier if non-empty, else empty. The role itself is always included; a
/// missing role is rendered as `"AXUnknown[<disambiguator>]"`.
public enum AXPathBuilder {

    public static func path(
        ancestors: [AXElementReference],
        target: AXElementReference
    ) -> [String] {
        (ancestors + [target]).map(component(for:))
    }

    private static func component(for ref: AXElementReference) -> String {
        let role = ref.role ?? "AXUnknown"
        return "\(role)[\(disambiguator(for: ref))]"
    }

    private static func disambiguator(for ref: AXElementReference) -> String {
        if let title = ref.title, !title.isEmpty { return title }
        if let id = ref.identifier, !id.isEmpty { return id }
        return ""
    }
}
