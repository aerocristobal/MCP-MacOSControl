// STORY-020 — App Compatibility Catalog
// COMPONENT: CompatibilityObservationStore — file I/O contract underneath the
// STORY-012 recorder. Proves the schema round-trips, retention caps per key,
// preserves prior data on append, and refuses to silently truncate on
// corruption (DoD: "STORY-012's test failure does NOT delete prior observations").

import XCTest
@testable import MacOSControlLib

final class CompatibilityObservationStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("STORY-020-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_read_returnsEmptyArray_whenFileDoesNotExist() throws {
        let url = tempDir.appendingPathComponent("never-written.json")
        let rows = try CompatibilityObservationStore.read(from: url)
        XCTAssertEqual(rows, [])
    }

    func test_writeThenRead_roundTripsAllFields() throws {
        let original = sampleRow(bundle: "com.apple.TextEdit", at: "2026-05-15T10:00:00Z")
        let url = tempDir.appendingPathComponent("rt.json")
        try CompatibilityObservationStore.write([original], to: url)
        let rows = try CompatibilityObservationStore.read(from: url)
        XCTAssertEqual(rows, [original])
    }

    func test_append_preservesPriorRows() throws {
        let url = tempDir.appendingPathComponent("append.json")
        try CompatibilityObservationStore.write([
            sampleRow(bundle: "com.apple.TextEdit", at: "2026-05-15T10:00:00Z")
        ], to: url)
        try CompatibilityObservationStore.append(
            sampleRow(bundle: "com.apple.calculator", at: "2026-05-16T10:00:00Z"),
            to: url
        )
        let rows = try CompatibilityObservationStore.read(from: url)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.bundleIdentifier)),
                       ["com.apple.TextEdit", "com.apple.calculator"])
    }

    func test_append_throws_whenFileIsCorrupted_andDoesNotOverwrite() throws {
        // DoD guard: a corrupted file must NOT be silently overwritten with
        // only the new observation; that would delete history. We surface the
        // error so a human can repair the file by hand.
        let url = tempDir.appendingPathComponent("corrupt.json")
        try "{not json".data(using: .utf8)!.write(to: url)
        XCTAssertThrowsError(try CompatibilityObservationStore.append(
            sampleRow(bundle: "com.apple.TextEdit", at: "2026-05-16T10:00:00Z"),
            to: url
        ))
        // File should still be the original corrupted bytes — untouched.
        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(String(data: bytes, encoding: .utf8), "{not json")
    }

    func test_applyRetentionLimit_keepsMostRecent50RowsPerKey() {
        let bundle = "com.example.app"
        let scenario = "noisy-scenario"
        // 60 rows for one (bundle, scenario): only the newest 50 survive.
        let rows = (0..<60).map { i -> CompatibilityObservation in
            sampleRow(
                bundle: bundle,
                at: String(format: "2026-01-%02dT00:00:00Z", (i % 28) + 1),
                scenario: scenario,
                method: "method-\(i)"
            )
        }
        let trimmed = CompatibilityObservationStore.applyRetentionLimit(rows)
        XCTAssertEqual(trimmed.count, CompatibilityObservationStore.perKeyHistoryLimit)
    }

    func test_applyRetentionLimit_doesNotMixHistoryAcrossKeys() {
        // 60 rows for app A + 60 rows for app B = 100 survivors (50 each).
        let rowsA = (0..<60).map { i in
            sampleRow(bundle: "a.app", at: "2026-01-01T00:00:\(String(format: "%02d", i % 60))Z", method: "m\(i)")
        }
        let rowsB = (0..<60).map { i in
            sampleRow(bundle: "b.app", at: "2026-01-02T00:00:\(String(format: "%02d", i % 60))Z", method: "m\(i)")
        }
        let trimmed = CompatibilityObservationStore.applyRetentionLimit(rowsA + rowsB)
        XCTAssertEqual(trimmed.filter { $0.bundleIdentifier == "a.app" }.count, 50)
        XCTAssertEqual(trimmed.filter { $0.bundleIdentifier == "b.app" }.count, 50)
    }

    func test_applyRetentionLimit_keepsAllRows_whenUnderCap() {
        let rows = (0..<3).map { i in
            sampleRow(bundle: "small.app", at: "2026-05-1\(i)T00:00:00Z", method: "m\(i)")
        }
        let trimmed = CompatibilityObservationStore.applyRetentionLimit(rows)
        XCTAssertEqual(trimmed.count, 3)
    }

    // MARK: - Helpers

    private func sampleRow(
        bundle: String,
        at timestamp: String,
        scenario: String = "scenario-x",
        method: String = "ax_semantic"
    ) -> CompatibilityObservation {
        CompatibilityObservation(
            bundleIdentifier: bundle,
            interactionMethod: method,
            macOSVersion: "14.5",
            timestamp: timestamp,
            scenarioName: scenario,
            tool: "smart_interact",
            registryExpectation: nil
        )
    }
}
