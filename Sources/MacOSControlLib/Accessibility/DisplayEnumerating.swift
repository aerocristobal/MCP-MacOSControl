import Foundation
import CoreGraphics

public protocol DisplayEnumerating {
    func enumerate() -> [DisplayInfo]
}

/// Real implementation backed by Quartz's `CGGetActiveDisplayList` /
/// `CGDisplayBounds`. Both return top-left-origin global coordinates
/// directly, so no Cocoa flip is needed (which is the highest-likelihood
/// source of silent coordinate-space bugs in this story).
public struct ActiveDisplayEnumerator: DisplayEnumerating {
    public init() {}

    public func enumerate() -> [DisplayInfo] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return []
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &ids, &displayCount) == .success else {
            return []
        }
        return ids.enumerated().map { (i, id) in
            DisplayInfo(index: i, frame: CGDisplayBounds(id))
        }
    }
}
