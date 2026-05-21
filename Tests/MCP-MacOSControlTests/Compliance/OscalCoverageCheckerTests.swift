// FILE: Tests/MCP-MacOSControlTests/Compliance/OscalCoverageCheckerTests.swift
// STORY: STORY-022 — OSCAL Component Definition
// Covers the BDD scenarios in docs/stories/STORY-022 §2 that the OSCAL CLI
// cannot itself enforce: SECURITY.md ↔ OSCAL drift, per-control source &
// test traceability, SBOM evidence link, and the SI-10 alternative-
// implementation requirement for accepted residual risk.

import XCTest
import OSCALComplianceSupport

final class OscalCoverageCheckerTests: XCTestCase {

    private var checker: OscalCoverageChecker!

    private func repoRoot() -> URL {
        // Tests run with the working directory set to the package root by
        // `swift test`. Anchor relative paths from there for stability.
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    override func setUp() {
        super.setUp()
        checker = OscalCoverageChecker(
            componentDefinitionPath: repoRoot().appendingPathComponent("oscal/component-definition.json").path,
            securityMdPath: repoRoot().appendingPathComponent("docs/SECURITY.md").path
        )
    }

    // MARK: - Control coverage

    func test_everyControlInSecurityMdHasOscalStatement() throws {
        let report = try checker.report()
        XCTAssertTrue(
            report.missingControls.isEmpty,
            "control_mapping_drift — controls claimed in docs/SECURITY.md without an OSCAL implemented-requirement: \(report.missingControls.sorted())"
        )
    }

    func test_oscalDoesNotImplementControlsAbsentFromSecurityMd() throws {
        let report = try checker.report()
        XCTAssertTrue(
            report.extraControls.isEmpty,
            "control_mapping_drift — OSCAL implements controls not referenced in docs/SECURITY.md §7/§8: \(report.extraControls.sorted()). Either remove the OSCAL statement or document the control in SECURITY.md."
        )
    }

    func test_supplyChainControls_SR3_SR4_SR11_arePresent() throws {
        let report = try checker.report()
        XCTAssertTrue(report.implementedControls.contains("sr-3"), "SR-3 missing from OSCAL implemented-requirements")
        XCTAssertTrue(report.implementedControls.contains("sr-4"), "SR-4 missing from OSCAL implemented-requirements")
        XCTAssertTrue(report.implementedControls.contains("sr-11"), "SR-11 missing from OSCAL implemented-requirements")
    }

    func test_componentDefinition_referencesSbomArtifact() throws {
        let doc = try checker.parsedComponentDefinition()
        let evidenceLinks = doc.links.filter { $0.rel == "evidence" }
        XCTAssertTrue(
            evidenceLinks.contains(where: { $0.href.contains("sbom-cyclonedx") }),
            "Component-level links must include an evidence link to sbom-cyclonedx — STORY-021 evidence handshake"
        )
    }

    // MARK: - Per-control source & test traceability

    func test_implementation_referencesSourceAndTestForControl_AU2() throws {
        let view = try checker.statement(for: "au-2")
        XCTAssertTrue(
            view.implementing_files.contains(where: { $0.contains("AuditRecorder.swift") }),
            "AU-2 must reference AuditRecorder.swift as implementing file"
        )
        XCTAssertTrue(
            view.test_files.contains(where: { $0.contains("AuditRecorder") }),
            "AU-2 must reference an AuditRecorder test file as verification"
        )
    }

    func test_implementation_referencesSourceAndTestForControl_SI10() throws {
        let view = try checker.statement(for: "si-10")
        XCTAssertTrue(
            view.implementing_files.contains(where: { $0.contains("AppleScriptSecurityFilter") }),
            "SI-10 must reference AppleScriptSecurityFilter as implementing file"
        )
        XCTAssertTrue(
            view.test_files.contains(where: { $0.contains("AppleScriptSecurityFilter") }),
            "SI-10 must reference AppleScriptSecurityFilter tests as verification"
        )
    }

    func test_implementation_referencesSourceAndTestForControl_CM7() throws {
        let view = try checker.statement(for: "cm-7")
        XCTAssertTrue(
            view.implementing_files.contains(where: {
                $0.contains("MCP-TOOL-CATALOG-AUDIT.md") || $0.contains("AppleScriptSecurityFilter")
            }),
            "CM-7 must reference the tool-catalog audit doc or the security filter as implementing"
        )
        XCTAssertTrue(
            view.test_files.contains(where: { $0.contains("ToolCatalogAudit") }),
            "CM-7 must reference ToolCatalogAuditTests as verification"
        )
    }

    func test_implementation_referencesSourceAndTestForControl_AC3() throws {
        let view = try checker.statement(for: "ac-3")
        XCTAssertTrue(
            view.implementing_files.contains(where: { $0.contains("AutomationPermissionChecker.swift") }),
            "AC-3 must reference AutomationPermissionChecker.swift (BDD §2 outline)"
        )
        XCTAssertFalse(
            view.test_files.isEmpty,
            "AC-3 must reference at least one test file from Tests/ (BDD §2 outline)"
        )
    }

    func test_implementation_referencesSourceAndTestForControl_AC4() throws {
        let view = try checker.statement(for: "ac-4")
        // BDD §2 outline expects AppleScriptSecurityFilter.swift; SECURITY.md §7.1
        // attributes the truncation cap to AppleScriptExecutor. Both gates apply to
        // information flow — assert both are present.
        XCTAssertTrue(
            view.implementing_files.contains(where: { $0.contains("AppleScriptSecurityFilter.swift") }),
            "AC-4 must reference AppleScriptSecurityFilter.swift per BDD §2 outline (inbound flow restriction)"
        )
        XCTAssertTrue(
            view.implementing_files.contains(where: { $0.contains("AppleScriptExecutor.swift") }),
            "AC-4 must reference AppleScriptExecutor.swift per SECURITY.md §7.1 (outbound flow restriction via 1 MB truncation)"
        )
        XCTAssertFalse(
            view.test_files.isEmpty,
            "AC-4 must reference at least one test file from Tests/ (BDD §2 outline)"
        )
    }

    func test_implementation_referencesSourceAndTestForControl_SR4() throws {
        let view = try checker.statement(for: "sr-4")
        XCTAssertTrue(
            view.implementing_files.contains(where: { $0.contains("ci.yml") }),
            "SR-4 (Provenance) must reference the CI workflow as the SBOM-generation implementation"
        )
    }

    // MARK: - Accepted residual risk encoded as alternative statements

    func test_si10_includesAlternativeStatement_forAcceptedBypassRisk() throws {
        let view = try checker.statement(for: "si-10")
        XCTAssertTrue(
            view.hasAlternativeImplementations,
            "SI-10 must encode the accepted bypass classes (SECURITY.md §4.1) as statement[].remarks entries — the OSCAL workaround for accepted-risk per Q5"
        )
    }

    func test_si10_documentsAllFourBypassClasses() throws {
        let doc = try checker.parsedComponentDefinition()
        guard let req = doc.implementedRequirements.first(where: { $0.controlId.lowercased() == "si-10" }),
              let statements = req.statements else {
            return XCTFail("SI-10 implemented-requirement is missing or has no statements")
        }
        XCTAssertGreaterThanOrEqual(
            statements.count, 4,
            "SECURITY.md §4.1 enumerates four accepted bypass classes; OSCAL must record one statement per class"
        )
        for statement in statements {
            XCTAssertNotNil(statement.remarks, "Bypass-class statement \(statement.statementId) must carry remarks with justification")
            XCTAssertFalse(statement.remarks?.isEmpty ?? true, "Bypass-class remarks must not be empty")
        }
    }

    func test_si10_remarks_referenceSecurityMdSection41JustificationAndReEvaluation() throws {
        // BDD §2 Scenario 5: "the statement's 'remarks' field contains the
        // SECURITY.md §4.1 justification and re-evaluation criteria". At least
        // one SI-10 statement must explicitly cite §4.1 and the re-evaluation
        // criterion (the AST parser availability) named in §4.1.
        let doc = try checker.parsedComponentDefinition()
        guard let req = doc.implementedRequirements.first(where: { $0.controlId.lowercased() == "si-10" }),
              let statements = req.statements else {
            return XCTFail("SI-10 implemented-requirement is missing or has no statements")
        }
        let aggregateRemarks = statements.compactMap { $0.remarks }.joined(separator: "\n").lowercased()
        XCTAssertTrue(
            aggregateRemarks.contains("§4.1") || aggregateRemarks.contains("section 4.1"),
            "SI-10 statement remarks must reference SECURITY.md §4.1 by section number"
        )
        XCTAssertTrue(
            aggregateRemarks.contains("ast parser") || aggregateRemarks.contains("ast-based"),
            "SI-10 statement remarks must reference the §4.1 re-evaluation criterion (AST parser availability)"
        )
        XCTAssertTrue(
            aggregateRemarks.contains("re-evaluation") || aggregateRemarks.contains("reevaluation"),
            "SI-10 statement remarks must spell out re-evaluation criteria per §4.1"
        )
    }

    func test_si10_bypassStatements_carryAlternativeImplementationStatusProp() throws {
        // BDD §2 Scenario 5: "a control statement of 'implementation-status: planned' or
        // 'alternative' exists for the bypass classes". The OSCAL workaround per Q5 is to
        // attach an implementation-status prop at the statement level.
        let doc = try checker.parsedComponentDefinition()
        guard let req = doc.implementedRequirements.first(where: { $0.controlId.lowercased() == "si-10" }),
              let statements = req.statements else {
            return XCTFail("SI-10 implemented-requirement is missing or has no statements")
        }
        let acceptableStatuses: Set<String> = ["alternative", "planned"]
        for statement in statements {
            let status = statement.props?.first { $0.name == "implementation-status" }?.value
            XCTAssertNotNil(status, "Statement \(statement.statementId) must declare an implementation-status prop")
            if let value = status {
                XCTAssertTrue(
                    acceptableStatuses.contains(value),
                    "Statement \(statement.statementId) implementation-status is \(value); BDD §2 Scenario 5 requires 'planned' or 'alternative'"
                )
            }
        }
    }

    // MARK: - Drift detection (synthetic SECURITY.md content)

    func test_drift_failsWhenSecurityMdNamesUnmappedControl() throws {
        let fakeSecurityMd = """
        ## 7. Compliance

        ### 7.1 Controls satisfied

        | Control | Title | How |
        |---|---|---|
        | **AU-2** | Event Logging | … |
        | **FAKE-99** | Hypothetical | Should be flagged as drift |
        """
        let driftChecker = OscalCoverageChecker(
            componentDefinitionPath: repoRoot().appendingPathComponent("oscal/component-definition.json").path,
            securityMdContent: fakeSecurityMd
        )
        let report = try driftChecker.report()
        XCTAssertTrue(
            report.missingControls.contains("fake-99"),
            "control_mapping_drift — synthetic fixture: drift detector should flag fake-99 as missing from OSCAL; got missingControls=\(report.missingControls.sorted())"
        )
    }

    func test_drift_passesWhenAllControlsAligned() throws {
        let report = try checker.report()
        XCTAssertEqual(
            report.missingControls.count, 0,
            "control_mapping_drift — \(report.missingControls.sorted()) are claimed in SECURITY.md but absent from oscal/component-definition.json"
        )
    }

    func test_drift_failsWhenOscalImplementsExtraControl() throws {
        let onlyAuTwo = """
        ## 7. Compliance

        ### 7.1 Controls satisfied

        | Control | Title | How |
        |---|---|---|
        | **AU-2** | Event Logging | … |
        """
        let driftChecker = OscalCoverageChecker(
            componentDefinitionPath: repoRoot().appendingPathComponent("oscal/component-definition.json").path,
            securityMdContent: onlyAuTwo
        )
        let report = try driftChecker.report()
        XCTAssertFalse(
            report.extraControls.isEmpty,
            "control_mapping_drift — synthetic fixture: when SECURITY.md only names AU-2 but OSCAL implements every other control, the extraControls set should be non-empty"
        )
        XCTAssertTrue(
            report.extraControls.contains("si-10"),
            "control_mapping_drift — synthetic drift run should surface si-10 as extra; got extraControls=\(report.extraControls.sorted())"
        )
    }
}
