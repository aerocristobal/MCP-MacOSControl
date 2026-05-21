// FILE: Tests/MCP-MacOSControlTests/Compliance/OscalObservationEmitterTests.swift
// STORY: STORY-037 — OSCAL Assessment Results & POA&M Artifacts
// COMPONENT: OscalObservationEmitter
//
// Covers the BDD scenarios in STORY-037 §2:
//   "A continuous-monitoring run converts AuditRecord events into observations"
//   "Hash-chain breaks generate a higher-severity observation"
//   "Assessment Results are continuously appended, not rewritten"

import XCTest
import MacOSControlLib
@testable import OSCALComplianceSupport

final class OscalObservationEmitterTests: XCTestCase {

    func test_emitter_producesOneObservationPerRecord() throws {
        let records = [
            AuditRecord.fixture(eventType: .applescriptExecute, filterDisposition: .allowed),
            AuditRecord.fixture(eventType: .applescriptExecute, filterDisposition: .rejectedSecurity)
        ]
        let obs = OscalObservationEmitter().observations(from: records)
        XCTAssertEqual(obs.count, 2, "Each AuditRecord must produce exactly one Observation")
    }

    func test_emitter_populatesCollectedTimestamp() throws {
        let ts = Date(timeIntervalSince1970: 1_747_000_000)
        let record = AuditRecord.fixture(timestamp: ts, eventType: .applescriptExecute, filterDisposition: .allowed)
        let obs = OscalObservationEmitter().observations(from: [record]).first
        XCTAssertEqual(obs?.collected, AuditTimestamp.format(ts))
    }

    func test_emitter_linksRelevantControls_forAppleScriptExecuted() throws {
        let record = AuditRecord.fixture(eventType: .applescriptExecute, filterDisposition: .allowed)
        let obs = OscalObservationEmitter().observations(from: [record]).first
        let controlLinks = (obs?.links ?? []).filter { $0.rel == "control" }.map { $0.href }
        XCTAssertEqual(Set(controlLinks), Set(["#au-2", "#au-3", "#cm-7"]))
    }

    func test_emitter_subjectsIdentifyToolTargetAppAndParty() throws {
        let record = AuditRecord.fixture(
            eventType: .applescriptExecute,
            targetApps: ["Mail"],
            filterDisposition: .allowed,
            hostIdentifier: "runner-37b6"
        )
        guard let obs = OscalObservationEmitter().observations(from: [record]).first else { return XCTFail() }
        let subjectTypes = (obs.subjects ?? []).map { $0.type }
        let subjectTitles = (obs.subjects ?? []).compactMap { $0.title }
        XCTAssertTrue(subjectTypes.contains("tool"))
        XCTAssertTrue(subjectTypes.contains("component"))
        XCTAssertTrue(subjectTypes.contains("party"))
        XCTAssertTrue(subjectTitles.contains("run_applescript"))
        XCTAssertTrue(subjectTitles.contains("Mail"))
        XCTAssertTrue(subjectTitles.contains("runner-37b6"))
    }

    func test_chainBreak_producesElevatedSeverityWithRelatedRiskProp() throws {
        let record = AuditRecord.fixture(eventType: .chainVerificationFailure)
        guard let obs = OscalObservationEmitter().observations(from: [record]).first else { return XCTFail() }
        XCTAssertEqual(obs.methods, ["TEST"])
        // OSCAL places risk → observation edges on the risk side; the
        // observation side carries an `elevated-severity` prop the
        // emitter uses to drive autoOpenChainBreakItems.
        XCTAssertTrue(obs.isElevated, "Chain-break observation must carry elevated-severity prop")
        let relatedRiskUuid = (obs.props ?? []).first { $0.name == "related-risk-uuid" }?.value
        XCTAssertEqual(relatedRiskUuid, OscalObservationEmitter.chainBreakRiskUuid,
                       "Chain-break observation prop must point at the chain-break risk UUID for cross-reference")
        XCTAssertTrue((obs.remarks ?? "").contains("ELEVATED"), "Chain-break remarks should mark severity")
    }

    func test_chainBreak_remarksIncludeChainOffsetAndMismatchDetail() throws {
        // STORY-037 §2 Scenario "Hash-chain breaks generate a higher-severity observation":
        //   "observation's 'remarks' field includes the chain offset and detected mismatch"
        let record = AuditRecord.fixture(
            eventType: .chainVerificationFailure,
            rejectionReason: "chain break detected at offset 42; prev_hash mismatch"
        )
        guard let obs = OscalObservationEmitter().observations(from: [record]).first else { return XCTFail() }
        let remarks = obs.remarks ?? ""
        XCTAssertTrue(remarks.contains("offset 42"), "Chain-break remarks must surface chain offset; got: \(remarks)")
        XCTAssertTrue(remarks.contains("prev_hash mismatch"), "Chain-break remarks must surface the mismatch detail; got: \(remarks)")
    }

    func test_chainBreakRiskUuid_matchesCommittedPoamRisk() throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("oscal/plan-of-action-and-milestones.json")
        let doc = try OscalPoamDocument.load(from: url)
        let uuids = doc.risks.map { $0.uuid.lowercased() }
        XCTAssertTrue(uuids.contains(OscalObservationEmitter.chainBreakRiskUuid.lowercased()),
                      "Committed POA&M must contain a risk with UUID == OscalObservationEmitter.chainBreakRiskUuid; otherwise auto-opened chain-break observations would dangle.")
    }

    func test_emitter_uuidsAreDeterministicAcrossRuns() throws {
        let recordId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let r1 = AuditRecord.fixture(recordId: recordId)
        let r2 = AuditRecord.fixture(recordId: recordId)
        let a = OscalObservationEmitter().observations(from: [r1]).first
        let b = OscalObservationEmitter().observations(from: [r2]).first
        XCTAssertEqual(a?.uuid, b?.uuid, "Observation UUID derivation must be deterministic from record_id")
    }

    func test_appender_preservesPriorObservations() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "ar-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }

        // Seed the doc with one observation, write it, reload, append a
        // second observation, and re-load. The original observation's
        // uuid and content must be unchanged.
        let seed = OscalAssessmentResultsDocument.empty
        let first = OscalObservationEmitter().observations(from: [
            AuditRecord.fixture(recordId: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!)
        ]).first!
        let withFirst = seed.appending(observations: [first], now: Date(timeIntervalSince1970: 1_747_000_100))
        try withFirst.write(to: url)

        let reloaded = try OscalAssessmentResultsDocument.load(from: url)
        XCTAssertEqual(reloaded.observations.count, 1)

        let second = AuditRecord.fixture(
            recordId: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
            eventType: .menuClick
        )
        let appended = OscalObservationEmitter().append(observationsFrom: [second], into: reloaded, now: Date(timeIntervalSince1970: 1_747_000_200))
        try appended.write(to: url)

        let finalDoc = try OscalAssessmentResultsDocument.load(from: url)
        XCTAssertEqual(finalDoc.observations.count, 2)
        // Original observation must be byte-equal.
        XCTAssertEqual(finalDoc.observations[0], reloaded.observations[0])
    }

    func test_appender_dedupesByObservationUuid() throws {
        // Same record_id twice in the input → only one observation appended.
        let record = AuditRecord.fixture()
        let emitter = OscalObservationEmitter()
        let doc1 = emitter.append(observationsFrom: [record], into: .empty)
        let doc2 = emitter.append(observationsFrom: [record], into: doc1)
        XCTAssertEqual(doc2.observations.count, 1, "Re-running the emitter on the same record must be idempotent")
    }

    // MARK: - POA&M ↔ AR cross-reference (auto-open on chain-break)

    func test_autoOpenChainBreakItems_appendsObservationUuidsToChainBreakRisk() throws {
        let record = AuditRecord.fixture(eventType: .chainVerificationFailure)
        let emitter = OscalObservationEmitter()
        let obs = emitter.observations(from: [record])
        let elevated = emitter.elevatedObservations(in: obs)
        XCTAssertEqual(elevated.count, 1, "Chain-break record must produce exactly one elevated observation")

        let poamUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("oscal/plan-of-action-and-milestones.json")
        let prior = try OscalPoamDocument.load(from: poamUrl)
        let updated = emitter.autoOpenChainBreakItems(in: prior, forElevatedObservations: elevated)

        guard let risk = updated.risks.first(where: { $0.uuid.lowercased() == OscalObservationEmitter.chainBreakRiskUuid.lowercased() }) else {
            return XCTFail("Chain-break Risk must exist for auto-open to land")
        }
        let refs = risk.relatedObservations ?? []
        XCTAssertTrue(refs.contains { $0.observationUuid == elevated[0].uuid },
                      "Chain-break Risk's related-observations must reference the new elevated observation")
    }

    func test_autoOpenChainBreakItems_isIdempotent() throws {
        let record = AuditRecord.fixture(eventType: .chainVerificationFailure)
        let emitter = OscalObservationEmitter()
        let elevated = emitter.elevatedObservations(in: emitter.observations(from: [record]))

        let poamUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("oscal/plan-of-action-and-milestones.json")
        let prior = try OscalPoamDocument.load(from: poamUrl)
        let first = emitter.autoOpenChainBreakItems(in: prior, forElevatedObservations: elevated)
        let second = emitter.autoOpenChainBreakItems(in: first, forElevatedObservations: elevated)

        let target = OscalObservationEmitter.chainBreakRiskUuid.lowercased()
        let firstRefs = first.risks.first(where: { $0.uuid.lowercased() == target })?.relatedObservations?.count ?? 0
        let secondRefs = second.risks.first(where: { $0.uuid.lowercased() == target })?.relatedObservations?.count ?? 0
        XCTAssertEqual(firstRefs, secondRefs, "Re-running auto-open must not duplicate related-observations")
    }

    func test_autoOpenChainBreakItems_noOpsWhenNoElevatedObservations() throws {
        let poamUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("oscal/plan-of-action-and-milestones.json")
        let prior = try OscalPoamDocument.load(from: poamUrl)
        let updated = OscalObservationEmitter().autoOpenChainBreakItems(in: prior, forElevatedObservations: [])
        XCTAssertEqual(updated, prior, "No elevated observations → POA&M must be byte-equal to prior")
    }

    func test_appender_updatesLastModified() throws {
        let beforeTs = Date(timeIntervalSince1970: 1_747_000_000)
        let afterTs  = Date(timeIntervalSince1970: 1_747_010_000)
        let seed = OscalAssessmentResultsDocument.empty
        let appended = OscalObservationEmitter().append(observationsFrom: [AuditRecord.fixture()], into: seed, now: afterTs)
        XCTAssertNotEqual(appended.assessmentResults.metadata.lastModified, seed.assessmentResults.metadata.lastModified,
                          "appending must bump last-modified")
        XCTAssertEqual(appended.assessmentResults.metadata.lastModified, OscalAssessmentResultsDocument.iso8601(afterTs))
        XCTAssertNotEqual(OscalAssessmentResultsDocument.iso8601(beforeTs), OscalAssessmentResultsDocument.iso8601(afterTs))
    }
}
