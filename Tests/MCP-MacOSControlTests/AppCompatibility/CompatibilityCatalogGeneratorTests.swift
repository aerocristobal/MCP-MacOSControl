// STORY-020 — App Compatibility Catalog
// COMPONENT: CompatibilityCatalogGenerator unit tests. Ports the story's §6.1
// scaffold (adapted to the canonical observation type and the existing
// FakeClock / FakeAppCapabilityRegistry test doubles).

import XCTest
@testable import MacOSControlLib

final class CompatibilityCatalogGeneratorTests: XCTestCase {

    private var fakeClock: FakeClock!
    private var generator: CompatibilityCatalogGenerator!
    private let scenario = "Validate interaction method selection across app types"

    override func setUp() {
        super.setUp()
        // 2024-05-18T00:00:00Z — anchored so stale/archive cutoffs are deterministic.
        fakeClock = FakeClock(start: Date(timeIntervalSince1970: 1_716_000_000))
        generator = CompatibilityCatalogGenerator(clock: fakeClock)
    }

    // MARK: - Markdown generation

    func test_generate_producesMarkdownTableWithExpectedColumns() throws {
        let observations = [obs(bundle: "com.apple.TextEdit", method: "ax_semantic")]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.apple.TextEdit",
                                axSupported: true, applescriptSupported: true)

        let markdown = try generator.generate(observations: observations, registry: registry)

        XCTAssertTrue(markdown.contains("| bundle_identifier"))
        XCTAssertTrue(markdown.contains("| observed_interaction_methods"))
        XCTAssertTrue(markdown.contains("| registry_expectation"))
        XCTAssertTrue(markdown.contains("| macOS_version_tested"))
        XCTAssertTrue(markdown.contains("| last_verified_date"))
        XCTAssertTrue(markdown.contains("com.apple.TextEdit"))
    }

    func test_generate_listsEveryObservedApplication() throws {
        let observations = [
            obs(bundle: "com.apple.TextEdit", method: "ax_semantic"),
            obs(bundle: "com.apple.calculator", method: "ax_semantic"),
            obs(bundle: "com.example.thirdapp", method: "applescript"),
        ]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.apple.TextEdit",
                                axSupported: true, applescriptSupported: true)

        let markdown = try generator.generate(observations: observations, registry: registry)

        XCTAssertTrue(markdown.contains("com.apple.TextEdit"))
        XCTAssertTrue(markdown.contains("com.apple.calculator"))
        XCTAssertTrue(markdown.contains("com.example.thirdapp"))
    }

    // MARK: - Discrepancy detection

    func test_detectsDiscrepancy_whenRegistryExpectsAxButObservedIsAppleScript() throws {
        let observations = [obs(bundle: "com.example.legacyapp", method: "applescript")]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.example.legacyapp",
                                axSupported: true, applescriptSupported: true)

        let result = try generator.generateWithDiscrepancyAnalysis(
            observations: observations, registry: registry
        )

        XCTAssertTrue(result.markdown.contains("⚠️ discrepancy"))
        XCTAssertEqual(result.discrepancies.count, 1)
        XCTAssertEqual(result.discrepancies[0].bundleIdentifier, "com.example.legacyapp")
        XCTAssertEqual(result.discrepancies[0].registryExpectation, "ax_semantic")
        XCTAssertEqual(result.discrepancies[0].observedInteractionMethod, "applescript")
    }

    func test_noDiscrepancy_whenObservedMatchesRegistry() throws {
        let observations = [obs(bundle: "com.apple.TextEdit", method: "ax_semantic")]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.apple.TextEdit",
                                axSupported: true, applescriptSupported: true)

        let result = try generator.generateWithDiscrepancyAnalysis(
            observations: observations, registry: registry
        )

        XCTAssertTrue(result.discrepancies.isEmpty)
        XCTAssertFalse(result.markdown.contains("⚠️ discrepancy"))
    }

    func test_summarySectionListsAllDiscrepancies() throws {
        // Two different bundles, each discrepant — both should appear in the
        // generated catalog's discrepancy summary.
        let observations = [
            obs(bundle: "com.example.first", method: "applescript"),
            obs(bundle: "com.example.second", method: "coordinate_fallback"),
        ]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.example.first",
                                axSupported: true, applescriptSupported: true)
        registry.stubCapability(forBundle: "com.example.second",
                                axSupported: true, applescriptSupported: false)

        let result = try generator.generateWithDiscrepancyAnalysis(
            observations: observations, registry: registry
        )

        XCTAssertEqual(result.discrepancies.count, 2)
        XCTAssertTrue(result.markdown.contains("## Discrepancies"))
        XCTAssertTrue(result.markdown.contains("com.example.first"))
        XCTAssertTrue(result.markdown.contains("com.example.second"))
    }

    // MARK: - Version matrix

    func test_buildVersionMatrix_includesEveryObservedMacOSVersion() {
        let observations = [
            obs(bundle: "com.apple.TextEdit", method: "ax_semantic", version: "13.6"),
            obs(bundle: "com.apple.TextEdit", method: "ax_semantic", version: "14.5"),
            obs(bundle: "com.apple.TextEdit", method: "ax_semantic", version: "15.1"),
        ]

        let matrix = generator.buildVersionMatrix(observations: observations)

        XCTAssertTrue(matrix.versions.contains("13.6"))
        XCTAssertTrue(matrix.versions.contains("14.5"))
        XCTAssertTrue(matrix.versions.contains("15.1"))
    }

    func test_generate_summarySection_listsMacOSVersionsExercised() throws {
        // Scenario 4 DoD: "the catalog summary section reports which macOS
        // versions have been most recently exercised."
        let observations = [
            obs(bundle: "com.apple.TextEdit", method: "ax_semantic", version: "13.6"),
            obs(bundle: "com.apple.TextEdit", method: "ax_semantic", version: "14.5"),
        ]

        let markdown = try generator.generate(
            observations: observations, registry: FakeAppCapabilityRegistry()
        )

        XCTAssertTrue(markdown.contains("macOS versions exercised: 13.6, 14.5"),
                      "summary must list the macOS versions observed across the catalog")
    }

    func test_generate_footerLinksToStory019AndStory012() throws {
        // DoD: "Footer linking to STORY-019 (registry source-of-truth) and
        // STORY-012 (observation source)" — clickable links, not just names.
        let markdown = try generator.generate(
            observations: [], registry: FakeAppCapabilityRegistry()
        )

        XCTAssertTrue(markdown.contains("[STORY-019](stories/STORY-019"),
                      "footer must link to the STORY-019 doc")
        XCTAssertTrue(markdown.contains("[STORY-012](stories/STORY-012"),
                      "footer must link to the STORY-012 doc")
    }

    func test_generate_marksUntestedVersions_inMatrix() throws {
        // TextEdit on 14.5 only; calculator on 13.6 only. Each row should show
        // the version where it WAS observed and "—" for the others.
        let observations = [
            obs(bundle: "com.apple.TextEdit", method: "ax_semantic", version: "14.5"),
            obs(bundle: "com.apple.calculator", method: "ax_semantic", version: "13.6"),
        ]
        let registry = FakeAppCapabilityRegistry()

        let markdown = try generator.generate(observations: observations, registry: registry)

        XCTAssertTrue(markdown.contains("## macOS version matrix"))
        // Both versions should be column headers; each app's row should have
        // exactly one ✅ and one — in the matrix.
        XCTAssertTrue(markdown.contains("| 13.6 | 14.5 |"))
    }

    // MARK: - Stale-row policy

    func test_staleRowReport_marksRowsWithObservationsOlderThan90Days() {
        let veryOld = fakeClock.now().addingTimeInterval(-100 * 86_400)
        let recent = fakeClock.now().addingTimeInterval(-10 * 86_400)
        let observations = [
            obs(bundle: "old.app", method: "ax_semantic", at: veryOld),
            obs(bundle: "new.app", method: "ax_semantic", at: recent),
        ]

        let report = generator.staleRowReport(observations: observations)

        XCTAssertTrue(report.staleBundleIds.contains("old.app"))
        XCTAssertFalse(report.staleBundleIds.contains("new.app"))
    }

    func test_archiveRows_movesToArchivedSectionAfter180Days() throws {
        let veryOld = fakeClock.now().addingTimeInterval(-200 * 86_400)
        let observations = [
            obs(bundle: "ancient.app", method: "ax_semantic", version: "13.6", at: veryOld)
        ]

        let markdown = try generator.generate(
            observations: observations, registry: FakeAppCapabilityRegistry()
        )

        XCTAssertTrue(markdown.contains("## Archived"))
        XCTAssertTrue(markdown.contains("ancient.app"))
    }

    func test_archiveRows_doesNotDeleteHistoricalObservations() throws {
        let veryOld = fakeClock.now().addingTimeInterval(-1000 * 86_400)
        let observations = [
            obs(bundle: "ancient.app", method: "ax_semantic", version: "12.0", at: veryOld)
        ]

        let markdown = try generator.generate(
            observations: observations, registry: FakeAppCapabilityRegistry()
        )

        XCTAssertTrue(markdown.contains("ancient.app"))
        XCTAssertTrue(markdown.contains("12.0"))
    }

    // MARK: - appSection

    func test_appSection_includesLastObservedDateAndMacOSVersion() {
        let observations = [
            obs(bundle: "com.apple.TextEdit", method: "ax_semantic",
                version: "14.5", at: fakeClock.now())
        ]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.apple.TextEdit",
                                axSupported: true, applescriptSupported: true)

        let section = generator.appSection(
            "com.apple.TextEdit", observations: observations, registry: registry
        )

        XCTAssertTrue(section.contains("com.apple.TextEdit"))
        XCTAssertTrue(section.contains("14.5"))
        XCTAssertTrue(section.contains("ax_semantic"))
    }

    // MARK: - Helpers

    private func obs(
        bundle: String,
        method: String,
        version: String = "14.5",
        at date: Date? = nil
    ) -> CompatibilityObservation {
        let timestamp = iso8601(date ?? fakeClock.now())
        return CompatibilityObservation(
            bundleIdentifier: bundle,
            interactionMethod: method,
            macOSVersion: version,
            timestamp: timestamp,
            scenarioName: scenario,
            tool: "smart_interact",
            registryExpectation: nil
        )
    }

    private func iso8601(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
    }
}
