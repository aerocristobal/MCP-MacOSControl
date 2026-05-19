// STORY-012 — End-to-End Integration Validation Suite
// Curated mapping from the integration feature file's scenario titles to the
// integration tests that prove them. Mirrors the unit suite's
// LivingDocumentationMapping pattern, scoped to the integration target so the
// per-PR unit living-doc CI gate is untouched.

enum IntegrationLivingDocMapping {

    static let scenarioToTests: [String: [String]] = [

        "Complete agent workflow — open, type, save a document": [
            "OpenTypeSaveWorkflowTests.test_workflow_open_type_save_producesFileOnDisk",
        ],
        "Validate interaction method selection across app types": [
            "SmartInteractRoutingTests.test_smartInteract_pickAxSemantic_forAxSupportedApp",
            "SmartInteractRoutingTests.test_smartInteract_fallsBack_forAxDegradedApp",
        ],
        "Confirm no regressions in existing coordinate-based tools": [
            "CoordinateToolBackCompatTests.test_coordinateTools_keepLegacyPlainTextResponses",
        ],
        "NSWorkspace launch flow — open Calculator from a not-running state": [
            "NSWorkspaceLaunchFlowTests.test_workflow_launchesCalculatorViaNSWorkspaceAndClicksButton",
        ],
        "Failure-recovery — smart_interact falls back and reports decision_log": [
            "SmartInteractFallbackTests.test_smartInteract_fallsBack_andReportsDecisionLog",
        ],
        "iPhone Mirroring smoke test — coordinate-based path is unaffected by Epic 6 changes": [
            "IPhoneSmokeTests.test_iphoneScreenshot_thenTap_changesScreen",
        ],
        "Mid-workflow permission revocation surfaces a structured error": [
            "PermissionRevocationTests.test_midWorkflowPermissionRevocation_surfacesStructuredError",
        ],
        "Structured-error contract honored across every error path": [
            "ErrorCodeContractTests.test_manifestCoversEveryRegisteredCode",
            "ErrorCodeContractTests.test_everyForcibleCode_returnsStructuredErrorEnvelope",
        ],
    ]
}
