import Foundation
import CoreGraphics

// STORY-010 — narrow seam over the existing coordinate-based MouseControl /
// KeyboardControl statics so `CoordinateLayer` is unit-testable without posting
// real CGEvents. The production conformance just forwards to the existing tools
// (no behavior change to them).

public protocol CoordinateActuating {
    func click(x: Int, y: Int) throws
    func typeText(_ text: String) async throws
}

public struct SystemCoordinateActuator: CoordinateActuating {
    public init() {}

    public func click(x: Int, y: Int) throws {
        try MouseControl.click(x: x, y: y, button: "left")
    }

    public func typeText(_ text: String) async throws {
        try await KeyboardControl.typeText(text: text)
    }
}
