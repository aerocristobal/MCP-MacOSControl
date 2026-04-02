import XCTest
import MCP
@testable import MacOSControlLib

final class CoreMLModuleTests: XCTestCase {
    func testLoadCoremlModelMissingParams() async throws {
        let result = try await CoreMLModule.handle(makeParams(name: "load_coreml_model"))
        XCTAssertEqual(result?.isError, true)
    }

    func testUnloadCoremlModelMissingParams() async throws {
        let result = try await CoreMLModule.handle(makeParams(name: "unload_coreml_model"))
        XCTAssertEqual(result?.isError, true)
    }

    func testGetModelInfoMissingParams() async throws {
        let result = try await CoreMLModule.handle(makeParams(name: "get_model_info"))
        XCTAssertEqual(result?.isError, true)
    }

    func testGenerateTextLlmMissingParams() async throws {
        let result = try await CoreMLModule.handle(makeParams(name: "generate_text_llm"))
        XCTAssertEqual(result?.isError, true)
    }

    func testAnalyzeScreenWithLlmMissingParams() async throws {
        let result = try await CoreMLModule.handle(makeParams(name: "analyze_screen_with_llm"))
        XCTAssertEqual(result?.isError, true)
    }

    func testExtractKeyInfoMissingParams() async throws {
        let result = try await CoreMLModule.handle(makeParams(name: "extract_key_info"))
        XCTAssertEqual(result?.isError, true)
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await CoreMLModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
