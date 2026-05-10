import Foundation

public protocol AXActionEnumerating {
    func actionNames(for ref: AXElementReference) throws -> [String]
}
