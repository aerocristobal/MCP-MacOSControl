// STORY-020 — App Compatibility Catalog CLI
// COMPONENT: Exit-code contract. Single-run discrepancy → 0 (warn-only);
// persistent (≥3 consecutive) → 2; aligned → 0. The Generator's behavior is
// covered by CompatibilityCatalogGeneratorTests; here we exercise file I/O
// and the warn/fail decision based on the same canonical fixtures CI will use.

import XCTest
@testable import MacOSControlLib

final class CatalogGeneratorCLITests: XCTestCase {

    func test_exit_returnsZero_whenAllObservationsAlignWithRegistry() async throws {
        let exitCode = await CatalogGeneratorCLI.run(
            observationsPath: fixtureURL("aligned-observations.json"),
            registryPath: fixtureURL("default-app-capabilities.json"),
            outputPath: tempOutputPath()
        )
        XCTAssertEqual(exitCode, CatalogGeneratorCLI.ExitCode.ok)
    }

    func test_exit_returnsNonZero_whenPersistentDiscrepancyPresent() async throws {
        let exitCode = await CatalogGeneratorCLI.run(
            observationsPath: fixtureURL("discrepant-observations-3-consecutive.json"),
            registryPath: fixtureURL("default-app-capabilities.json"),
            outputPath: tempOutputPath()
        )
        XCTAssertEqual(exitCode, CatalogGeneratorCLI.ExitCode.persistentDiscrepancy)
    }

    func test_exit_returnsZero_whenSingleRunDiscrepancyOnly() async throws {
        // Single-run discrepancy → warning only, not a failure.
        let exitCode = await CatalogGeneratorCLI.run(
            observationsPath: fixtureURL("discrepant-observations-single-run.json"),
            registryPath: fixtureURL("default-app-capabilities.json"),
            outputPath: tempOutputPath()
        )
        XCTAssertEqual(exitCode, CatalogGeneratorCLI.ExitCode.ok)
    }

    func test_writesMarkdownToOutputPath_evenWhenAligned() async throws {
        let output = tempOutputPath()
        _ = await CatalogGeneratorCLI.run(
            observationsPath: fixtureURL("aligned-observations.json"),
            registryPath: fixtureURL("default-app-capabilities.json"),
            outputPath: output
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let markdown = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(markdown.contains("# App Compatibility Catalog"))
    }

    func test_exit_returnsDataError_whenObservationsFileMissing() async throws {
        let exitCode = await CatalogGeneratorCLI.run(
            observationsPath: URL(fileURLWithPath: "/tmp/__STORY-020-nonexistent.json"),
            registryPath: URL(fileURLWithPath: "/tmp/__STORY-020-nonexistent-registry.json"),
            outputPath: tempOutputPath()
        )
        XCTAssertEqual(exitCode, CatalogGeneratorCLI.ExitCode.dataError)
    }

    // MARK: - Helpers

    private func fixtureURL(_ name: String) -> URL {
        guard let url = Bundle.module.url(
            forResource: (name as NSString).deletingPathExtension,
            withExtension: (name as NSString).pathExtension,
            subdirectory: "AppCompatibilityFixtures"
        ) else {
            XCTFail("Fixture \(name) not found in test bundle")
            return URL(fileURLWithPath: "/dev/null")
        }
        return url
    }

    private func tempOutputPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("STORY-020-\(UUID().uuidString).md")
    }
}
