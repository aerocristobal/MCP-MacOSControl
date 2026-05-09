import Foundation

public protocol AXElementResolving {
    func findElement(
        role: String?,
        title: String?,
        scope: AXResolverScope?
    ) throws -> AXElementReference

    func findElement(
        by kind: AXAttributeKind,
        value: String,
        scope: AXResolverScope?
    ) throws -> AXElementReference
}
