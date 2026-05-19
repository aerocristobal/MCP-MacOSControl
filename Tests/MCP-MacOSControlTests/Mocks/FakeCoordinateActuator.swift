import Foundation
@testable import MacOSControlLib

// STORY-010 — records coordinate-fallback dispatch without posting CGEvents.
final class FakeCoordinateActuator: CoordinateActuating {

    var clickError: Error?
    var typeError: Error?

    private(set) var clickCallCount = 0
    private(set) var lastClick: (x: Int, y: Int)?
    private(set) var typedText: [String] = []

    func click(x: Int, y: Int) throws {
        clickCallCount += 1
        lastClick = (x, y)
        if let clickError { throw clickError }
    }

    func typeText(_ text: String) async throws {
        if let typeError { throw typeError }
        typedText.append(text)
    }
}
