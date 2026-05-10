import Foundation

public final class AXActionEnumerator: AXActionEnumerating {
    private let bridge: AXApplicationBridge

    public init(bridge: AXApplicationBridge) {
        self.bridge = bridge
    }

    public func actionNames(for ref: AXElementReference) throws -> [String] {
        try bridge.copyActionNames(ref)
    }
}
