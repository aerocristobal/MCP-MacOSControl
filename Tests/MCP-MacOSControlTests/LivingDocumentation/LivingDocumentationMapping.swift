// Curated mapping from BDD scenario titles (in Tests/.../Features/*.feature)
// to the unit tests that prove their behavior. The generator asserts that
// every parsed scenario title appears as a key here — adding a new scenario
// without a mapping fails the build.

enum LivingDocumentationMapping {

    static let scenarioToTests: [String: [String]] = [

        // MARK: STORY-001 — AX Element Resolver Service

        "Resolve element by exact accessibility role and title": [
            "AXElementResolverTests.test_findElement_returnsElement_whenRoleAndTitleMatch",
            "AXElementResolverTests.test_findElement_returnsFirstMatch_whenMultipleCandidatesExist",
            "AXElementResolverTests.test_findElement_descendsThroughChildren",
        ],
        "Resolve element by accessibility identifier": [
            "AXElementResolverTests.test_findElement_byIdentifier_returnsMatchingElement",
            "AXElementResolverTests.test_findElement_byAttribute_descendsThroughChildren",
        ],
        "Return structured error when element is not found": [
            "AXElementResolverTests.test_findElement_throwsAXNotFoundError_whenNoMatchExists",
            "AXElementResolverTests.test_findElement_doesNotCrash_whenBridgeReturnsAXErrorCannotComplete",
            "AXElementResolverTests.test_findElement_byAttribute_throwsNotFound_whenNoMatch",
            "AXResolverErrorsTests.test_axNotFoundError_descriptionIncludesCriteria",
            "AXResolverErrorsTests.test_axNotFoundError_localizedDescriptionIncludesCriteria",
            "AXResolverErrorsTests.test_axNotFoundError_toResultIsErrorTrue",
        ],
        "Resolve element scoped to a specific application": [
            "AXElementResolverTests.test_findElement_scopedToApplication_excludesOtherProcesses",
            "AXElementResolverTests.test_findElement_scopeAcceptsBundleIdOrPid",
            "AXElementResolverTests.test_findElement_scopeAcceptsLocalizedName",
        ],
        "Handle resolution across supported element attribute types": [
            "AXElementResolverTests.test_findElement_byRole_returnsMatchingElement",
            "AXElementResolverTests.test_findElement_byTitle_returnsMatchingElement",
            "AXElementResolverTests.test_findElement_byIdentifier_returnsMatchingElement",
            "AXElementResolverTests.test_findElement_byLabel_returnsMatchingElement",
            "AXElementResolverTests.test_findElement_byDescription_returnsMatchingElement",
        ],

        // MARK: STORY-002 — Semantic Element Click Tool

        "Click a button identified by title": [
            "ClickElementToolTests.test_execute_callsResolverWithProvidedRoleAndTitle",
            "ClickElementToolTests.test_execute_dispatchesAXPressOnResolvedElement",
            "ClickElementToolTests.test_execute_responseIncludesAXIdentifier",
            "AXElementInteractorTests.test_performPress_invokesAXPerformAction_withKAXPressAction",
            "AXElementInteractorTests.test_performPress_doesNotMutateElement",
        ],
        "Click a checkbox by accessibility label": [
            "ClickElementToolTests.test_execute_passesLabelLocatorToResolver",
            "ClickElementToolTests.test_execute_responseIncludesPostActionState_whenReturnStateIsTrue",
            "ClickElementToolTests.test_execute_doesNotIncludeValue_whenReturnStateIsFalseOrAbsent",
        ],
        "Return error when element is not visible": [
            "ClickElementToolTests.test_execute_returnsElementNotFoundError_whenResolverThrows",
            "ClickElementToolTests.test_execute_doesNotDispatchPress_whenResolutionFails",
            "ClickElementToolTests.test_execute_returnsResolutionError_whenResolverThrowsAXResolutionError",
        ],
        "Click element in a specific application scope": [
            "ClickElementToolTests.test_execute_appliesBundleIdScope_whenApplicationContainsDot",
            "ClickElementToolTests.test_execute_appliesNameScope_whenApplicationIsBareName",
        ],

        // MARK: STORY-003 — AX Action Performer Tool

        "Perform AXPress on a button": [
            "PerformAXActionToolTests.test_execute_dispatchesAXPress_viaInteractor",
            "PerformAXActionToolTests.test_execute_responseIncludesActionAndIdentifier_onSuccess",
            "AXElementInteractorActionTests.test_performPress_stillFunctional_afterStory003Refactor",
        ],
        "Perform AXShowMenu on a pop-up button": [
            "PerformAXActionToolTests.test_execute_dispatchesAXShowMenu_viaInteractor",
            "AXElementInteractorActionTests.test_perform_dispatchesCorrectActionConstant",
        ],
        "Return supported actions list when action is not specified": [
            "PerformAXActionToolTests.test_execute_returnsActionList_whenActionOmitted",
            "PerformAXActionToolTests.test_execute_returnsActionList_whenActionIsEmptyString",
            "AXActionEnumeratorTests.test_actionNames_returnsActionsFromBridge",
            "AXActionEnumeratorTests.test_actionNames_returnsEmptyArray_forElementWithNoActions",
            "AXActionEnumeratorTests.test_actionNames_passesElementReferenceThroughToBridge",
        ],
        "Return error for unsupported action on element": [
            "PerformAXActionToolTests.test_execute_returnsActionNotSupportedError_withSupportedList",
            "PerformAXActionToolTests.test_execute_actionNotSupportedError_includesAlternatives",
            "PerformAXActionToolTests.test_execute_rejectsUnknownAction_whenAllowCustomIsFalse",
            "PerformAXActionToolTests.test_execute_rejectsCustomAction_whenAllowCustomTrueButElementDoesNotSupportIt",
            "AXActionEnumeratorTests.test_actionNames_throwsWhenAXAPIReturnsError",
            "AXElementInteractorActionTests.test_perform_wrapsBridgeFailureAsActionFailedError",
        ],
        "Support all standard AX named actions": [
            "AXElementInteractorActionTests.test_perform_dispatchesEachStandardActionUnchanged",
            "AXElementInteractorActionTests.test_perform_dispatchesCorrectActionConstant",
            "PerformAXActionToolTests.test_execute_dispatchesEachStandardAction",
        ],

        // MARK: STORY-004 — Enhanced Accessibility Tree Tool

        "Tree includes action names for interactive elements": [
            "AccessibilityTreeBuilderTests.test_build_includesAXActionNames_forInteractiveNodes",
            "AccessibilityTreeBuilderTests.test_build_skipsActionLookup_forKnownNonInteractiveRoles",
            "AccessibilityTreeBuilderTests.test_build_callsActionLookup_onlyForInteractiveRoles_inMixedTree",
            "AXNodeSerializerTests.test_serialize_includesActionsList_whenPresent",
            "AXNodeSerializerTests.test_serialize_omitsActionsList_whenEmpty",
        ],
        "Tree marks disabled elements with enabled = false": [
            "AccessibilityTreeBuilderTests.test_build_setsEnabledFalse_forDisabledElements",
            "AccessibilityTreeBuilderTests.test_build_omitsEnabled_whenAttributeUnsupported",
            "AXNodeSerializerTests.test_serialize_enabledFalse_whenAXEnabledIsFalse",
            "AXNodeSerializerTests.test_serialize_enabledTrue_whenAXEnabledIsTrue",
            "AXNodeSerializerTests.test_serialize_omitsEnabledField_whenAttributeUnsupported",
        ],
        "Tree includes AXIdentifier when available": [
            "AccessibilityTreeBuilderTests.test_build_propagatesIdentifierFromReference",
            "AXNodeSerializerTests.test_serialize_includesIdentifier_whenAXIdentifierIsNonNil",
            "AXNodeSerializerTests.test_serialize_omitsIdentifier_whenAXIdentifierIsNil",
            "AXNodeSerializerTests.test_serialize_omitsIdentifier_whenAXIdentifierIsEmptyString",
        ],
        "Tree includes settable flag for text fields and sliders": [
            "AccessibilityTreeBuilderTests.test_build_setsSettableTrue_forTextFieldWithSettableValue",
            "AccessibilityTreeBuilderTests.test_build_setsSettableTrue_forSlider",
            "AXNodeSerializerTests.test_serialize_settableTrue_forAXTextField_whenValueSettable",
            "AXNodeSerializerTests.test_serialize_settableTrue_forAXSlider",
            "AXNodeSerializerTests.test_serialize_settableFalse_forAXStaticText",
            "AXNodeSerializerTests.test_serialize_omitsSettableField_whenNil",
        ],
        "Tree supports depth limiting to prevent oversized payloads": [
            "AccessibilityTreeBuilderTests.test_build_prunesNodes_beyondMaxDepth",
            "AccessibilityTreeBuilderTests.test_build_setsTruncatedFlag_onParentWithPrunedChildren",
            "AccessibilityTreeBuilderTests.test_build_noTruncatedFlag_whenTreeFitsWithinMaxDepth",
            "AccessibilityTreeBuilderTests.test_build_noTruncatedFlag_onLeafNodes",
            "AXNodeSerializerTests.test_serialize_includesTruncated_whenSet",
            "AXNodeSerializerTests.test_serialize_omitsTruncated_whenNil",
            "AXNodeSerializerTests.test_serialize_emitsChildCount_whenChildrenPrunedAndCountKnown",
        ],
        "Pre-existing fields remain unchanged for backward compatibility": [
            "AXNodeSerializerTests.test_serialize_includesAllPreExistingFields",
            "AXNodeSerializerTests.test_serialize_includesDescription_whenPresent",
            "AXNodeSerializerTests.test_serialize_includesStringValue_asString",
            "AXNodeSerializerTests.test_serialize_includesNumericValue_asNumber",
            "AXNodeSerializerTests.test_serializeRoot_includesSchemaVersion2_atTopLevel",
            "AXNodeSerializerTests.test_serializeRoot_keepsRootFieldsAtTopLevel_forBackwardCompatibility",
        ],

        // MARK: STORY-005 — Element At Position Hit-Test Tool

        "Returns element details for a coordinate within a button": [
            "ElementAtPositionToolTests.test_execute_callsBridgeWithGlobalCoordinates",
            "ElementAtPositionToolTests.test_execute_returnsElementWithRoleAndTitle",
            "ElementAtPositionToolTests.test_execute_responseIncludesFrameForMatchedElement",
        ],
        "Returns element details for a coordinate within a text field": [
            "ElementAtPositionToolTests.test_execute_includesSettableTrue_forTextField",
            "ElementAtPositionToolTests.test_execute_responseIncludesSchemaVersion2",
        ],
        "Returns background element when coordinate is over an empty area": [
            "ElementAtPositionToolTests.test_execute_returnsApplicationRoot_whenNoSpecificElementAtCoords",
        ],
        "Returns error when coordinates are outside any attached display": [
            "ElementAtPositionToolTests.test_execute_rejectsCoords_outsideDisplayUnion",
            "ElementAtPositionToolTests.test_execute_doesNotInvokeBridge_whenOutOfBounds",
            "ElementAtPositionToolTests.test_execute_rejectsUnknownDisplayIndex",
            "DisplayBoundsValidatorTests.test_validate_passesAtExactDisplayBoundary",
            "DisplayBoundsValidatorTests.test_validate_passesAtExactUnionMaxCorner",
            "DisplayBoundsValidatorTests.test_validate_passesForCoordsInsideDisplay0",
            "DisplayBoundsValidatorTests.test_validate_passesForCoordsInsideDisplay1",
            "DisplayBoundsValidatorTests.test_unionBounds_isUnionOfAllDisplays",
        ],
        "Returns error when coordinates are not finite": [
            "ElementAtPositionToolTests.test_execute_rejectsNaN_x",
            "ElementAtPositionToolTests.test_execute_rejectsInfinite_y",
        ],

        // MARK: STORY-006 — run_applescript MCP Tool

        "Execute a simple AppleScript and return the result": [
            "RunAppleScriptToolTests.test_execute_invokesExecutor_withProvidedScript",
            "RunAppleScriptToolTests.test_execute_responseIncludesDurationMs",
            "RunAppleScriptToolTests.test_execute_responseIncludesStdoutAsResult",
            "RunAppleScriptToolTests.test_execute_responseIncludesTruncatedFalse_forNormalOutput",
            "AppleScriptExecutorTests.test_run_returnsStdout_forSimpleExpression",
        ],
        "Execute an AppleScript that modifies application state": [
            "RunAppleScriptToolTests.test_execute_returnsSuccess_forStateMutatingScript",
            "RunAppleScriptToolTests.test_execute_responseIncludesTruncatedTrue_whenOutputCapped",
        ],
        "Return structured error for a syntax error in the script": [
            "RunAppleScriptToolTests.test_execute_returnsAppleScriptError_forSyntaxError",
            "RunAppleScriptToolTests.test_execute_emitsAuditRecord_onScriptError",
            "AppleScriptExecutorTests.test_run_returnsScriptError_forSyntaxError",
        ],
        "Return timeout error when script exceeds execution limit": [
            "RunAppleScriptToolTests.test_execute_returnsTimeoutError_whenExecutorTimesOut",
            "RunAppleScriptToolTests.test_execute_passesDefaultTimeout_whenOmitted",
            "RunAppleScriptToolTests.test_execute_clampsTimeout_belowMinimum",
            "RunAppleScriptToolTests.test_execute_clampsTimeout_aboveMaximum",
            "RunAppleScriptToolTests.test_execute_emitsAuditRecord_onTimeout",
            "AppleScriptExecutorTests.test_run_terminatesProcess_afterTimeout",
        ],
        "Sanitize and reject scripts containing shell injection patterns": [
            "RunAppleScriptToolTests.test_execute_rejectsScript_withSecurityPolicyViolation",
            "RunAppleScriptToolTests.test_execute_doesNotInvokeExecutor_whenFilterRejects",
            "RunAppleScriptToolTests.test_execute_emitsAuditRecord_onSecurityRejection",
            "AppleScriptSecurityFilterTests.test_validate_rejectsDoShellScript",
            "AppleScriptSecurityFilterTests.test_validate_rejectsDoShellScript_caseInsensitive",
            "AppleScriptSecurityFilterTests.test_validate_rejectsDoShellScript_withExtraWhitespace",
            "AppleScriptSecurityFilterTests.test_validate_rejectsDoShellScript_evenAfterCommentStripping",
            "AppleScriptSecurityFilterTests.test_validate_rejectsDoJavaScript",
            "AppleScriptSecurityFilterTests.test_validate_rejectsLoadScript",
            "AppleScriptSecurityFilterTests.test_validate_rejectsSshPath",
            "AppleScriptSecurityFilterTests.test_validate_rejectsEtcPath",
            "AppleScriptSecurityFilterTests.test_validate_rejectsPrivatePath",
            "AppleScriptSecurityFilterTests.test_validate_rejectsPathTraversal",
            "AppleScriptSecurityFilterTests.test_validate_rejectsSystemEventsTell",
            "AppleScriptSecurityFilterTests.test_validate_errorIncludesMatchedRuleName",
            "AppleScriptSecurityFilterTests.test_validate_allowsCleanTellBlock",
            "AppleScriptSecurityFilterTests.test_validate_allowsArithmetic",
            "AppleScriptSecurityFilterTests.test_validate_allowsMultilineTellBlock",
            "AppleScriptSecurityFilterTests.test_validate_allowsMatchOnlyInsideStrippedComment",
            "AppleScriptSecurityFilterTests.test_validate_doesNotRejectMatch_inStringLiteralOnly",
        ],
        "Detect missing automation permission for target application": [
            "RunAppleScriptToolTests.test_execute_returnsAutomationPermissionRequired_whenCheckerDenies",
            "RunAppleScriptToolTests.test_execute_doesNotInvokeExecutor_whenPermissionDenied",
            "RunAppleScriptToolTests.test_execute_proceeds_whenPermissionGranted",
            "RunAppleScriptToolTests.test_execute_proceeds_whenScriptHasNoStaticTellClause",
            "RunAppleScriptToolTests.test_execute_emitsAuditRecord_onPermissionDenial",
            "AutomationPermissionCheckerTests.test_check_returnsDenied_forUngrantedApp",
            "AutomationPermissionCheckerTests.test_check_returnsSkipped_whenNoStaticTellClause",
            "AutomationPermissionCheckerTests.test_extractTargetApps_findsSingleTellClause",
            "AutomationPermissionCheckerTests.test_extractTargetApps_findsMultipleTellClauses",
            "AutomationPermissionCheckerTests.test_extractTargetApps_handlesQuotedAppNamesWithSpaces",
            "AutomationPermissionCheckerTests.test_extractTargetApps_isCaseInsensitive",
            "AutomationPermissionCheckerTests.test_extractTargetApps_returnsEmpty_forScriptWithoutTellClause",
            "AutomationPermissionCheckerTests.test_extractTargetApps_deduplicatesWithinScript",
        ],

        // MARK: STORY-007 — click_menu_item MCP Tool

        "Activate a top-level menu item": [
            "ClickMenuItemToolTests.test_execute_callsBackendWithNormalizedPath",
            "ClickMenuItemToolTests.test_execute_invokesBackendOnce_perCall",
            "AppleScriptMenuClickBackendTests.test_click_returnsSuccess_whenExecutorSucceeds",
            "AppleScriptMenuClickBackendTests.test_click_invokesResolverThenExecutor",
            "MenuPathResolverTests.test_script_generatesTwoLevelPath",
            "MenuPathResolverTests.test_script_includesActivationByDefault",
            "MenuPathResolverTests.test_script_quotesApplicationNameCorrectly",
        ],
        "Activate a nested submenu item": [
            "ClickMenuItemToolTests.test_execute_supportsThreeLevelNestedPath",
            "MenuPathResolverTests.test_script_generatesThreeLevelNestedPath",
        ],
        "Return error for a disabled menu item": [
            "ClickMenuItemToolTests.test_execute_returnsMenuItemDisabledError_whenBackendReportsDisabled",
            "AppleScriptMenuClickBackendTests.test_click_mapsDisabledErrorFromOsascriptStderr",
            "MenuPathResolverTests.test_script_includesEnabledCheck",
        ],
        "Return error when menu path is not found": [
            "ClickMenuItemToolTests.test_execute_returnsMenuItemNotFoundError_withAlternativesFromBackend",
            "ClickMenuItemToolTests.test_execute_rejectsEmptyPath",
            "ClickMenuItemToolTests.test_execute_rejectsPathExceedingDepthLimit",
            "ClickMenuItemToolTests.test_execute_rejectsMissingPath",
            "ClickMenuItemToolTests.test_execute_rejectsPathThatNormalizesToEmpty",
            "AppleScriptMenuClickBackendTests.test_click_mapsNotFoundErrorFromOsascriptStderr",
            "AppleScriptMenuClickBackendTests.test_alternatives_invokesResolverAlternativesScript",
            "AppleScriptMenuClickBackendTests.test_alternativesScript_returnsEnumerationOfFailingLevel",
            "AppleScriptMenuClickBackendTests.test_alternativesScript_threeLevelPathEnumeratesIntermediateMenu",
            "AppleScriptMenuClickBackendTests.test_alternativesScript_singleElementPathEnumeratesMenuBar",
        ],
    ]
}
