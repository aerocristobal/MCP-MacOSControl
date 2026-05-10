import Foundation
import CoreGraphics

public struct UnknownDisplayIndexError: Error, CustomStringConvertible {
    public let index: Int
    public let known: [Int]
    public var description: String {
        "unknown_display_index: requested \(index); known indices: \(known)"
    }
}

/// Translates display-local `(x, y)` coordinates into the global,
/// top-left-origin coordinate space used by `AXUIElementCopyElementAtPosition`.
/// When `displayIndex` is nil, the input is assumed to already be global and
/// returned unchanged.
public struct DisplayCoordinateTranslator {
    public let displays: [DisplayInfo]

    public init(displays: [DisplayInfo]) {
        self.displays = displays
    }

    public func toGlobal(x: CGFloat, y: CGFloat, displayIndex: Int?) throws -> CGPoint {
        guard let displayIndex else {
            return CGPoint(x: x, y: y)
        }
        guard let display = displays.first(where: { $0.index == displayIndex }) else {
            throw UnknownDisplayIndexError(index: displayIndex, known: displays.map { $0.index })
        }
        return CGPoint(x: x + display.frame.origin.x, y: y + display.frame.origin.y)
    }
}
