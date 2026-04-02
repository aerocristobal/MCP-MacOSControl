import XCTest
import MCP
@testable import MacOSControlLib

final class VisionModuleTests: XCTestCase {
    func testClassifyImageMissingParams() async throws {
        let result = try await VisionModule.handle(makeParams(name: "classify_image"))
        XCTAssertEqual(result?.isError, true)
    }

    func testDetectObjectsMissingParams() async throws {
        let result = try await VisionModule.handle(makeParams(name: "detect_objects"))
        XCTAssertEqual(result?.isError, true)
    }

    func testDetectRectanglesMissingParams() async throws {
        let result = try await VisionModule.handle(makeParams(name: "detect_rectangles"))
        XCTAssertEqual(result?.isError, true)
    }

    func testDetectSaliencyMissingParams() async throws {
        let result = try await VisionModule.handle(makeParams(name: "detect_saliency"))
        XCTAssertEqual(result?.isError, true)
    }

    func testDetectFacesMissingParams() async throws {
        let result = try await VisionModule.handle(makeParams(name: "detect_faces"))
        XCTAssertEqual(result?.isError, true)
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await VisionModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
