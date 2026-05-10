import Foundation
import CoreGraphics

/// Identification + frame for a single attached display, expressed in
/// top-left-origin global coordinates (matching Quartz `CGDisplayBounds`
/// and the AX C-API). `index` is the position in the active display list
/// returned by `CGGetActiveDisplayList`; index 0 is the main display.
public struct DisplayInfo: Equatable, Sendable {
    public let index: Int
    public let frame: CGRect

    public init(index: Int, frame: CGRect) {
        self.index = index
        self.frame = frame
    }
}
