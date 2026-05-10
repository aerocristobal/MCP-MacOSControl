import Foundation
import CoreGraphics

public struct InvalidCoordinatesError: Error, CustomStringConvertible {
    public let detail: String
    public var description: String { "invalid_coordinates: \(detail)" }
}

public struct CoordinatesOutOfBoundsError: Error, CustomStringConvertible {
    public let x: CGFloat
    public let y: CGFloat
    public let unionBounds: CGRect
    public var description: String {
        let w = Int(unionBounds.width)
        let h = Int(unionBounds.height)
        return "coordinates_out_of_bounds: (\(x), \(y)) is outside display union (\(w)x\(h) starting at (\(Int(unionBounds.origin.x)), \(Int(unionBounds.origin.y))))"
    }
}

/// Validates a global `(x, y)` against the union of attached display frames.
/// Coordinates that are not finite (NaN, ±Infinity) are rejected up front.
/// Boundary semantics are closed-on-min, closed-on-max so that points lying
/// exactly on a shared edge between two displays still validate (matches
/// `DisplayBoundsValidatorTests.test_validate_passesAtExactDisplayBoundary`).
public struct DisplayBoundsValidator {
    public let displays: [DisplayInfo]

    public init(displays: [DisplayInfo]) {
        self.displays = displays
    }

    public func validate(x: CGFloat, y: CGFloat) throws {
        if !x.isFinite {
            throw InvalidCoordinatesError(detail: "x is not finite (got \(x))")
        }
        if !y.isFinite {
            throw InvalidCoordinatesError(detail: "y is not finite (got \(y))")
        }
        if displays.contains(where: { contains($0.frame, x: x, y: y) }) {
            return
        }
        throw CoordinatesOutOfBoundsError(x: x, y: y, unionBounds: unionBounds())
    }

    public func unionBounds() -> CGRect {
        guard let first = displays.first?.frame else { return .zero }
        return displays.dropFirst().reduce(first) { $0.union($1.frame) }
    }

    private func contains(_ rect: CGRect, x: CGFloat, y: CGFloat) -> Bool {
        x >= rect.minX && x <= rect.maxX && y >= rect.minY && y <= rect.maxY
    }
}
