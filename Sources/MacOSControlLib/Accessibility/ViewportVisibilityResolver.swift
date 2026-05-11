import Foundation
import CoreGraphics

public final class ViewportVisibilityResolver {

    public init() {}

    /// Returns whether `nodeFrame` intersects `windowFrame` by at least one pixel.
    /// Returns `nil` when either frame is missing — callers should treat `nil`
    /// as the omit-from-JSON signal. A zero-area node is reported `false`.
    public func isVisible(nodeFrame: CGRect?, in windowFrame: CGRect?) -> Bool? {
        guard let nodeFrame, let windowFrame else { return nil }
        if nodeFrame.width <= 0 || nodeFrame.height <= 0 { return false }
        let intersection = nodeFrame.intersection(windowFrame)
        return !intersection.isNull && !intersection.isEmpty
    }
}
