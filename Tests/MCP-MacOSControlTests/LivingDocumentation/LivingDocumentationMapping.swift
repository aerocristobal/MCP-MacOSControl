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
            "AXResolverErrorsTests.test_axNotFoundError_toStructuredResult_isErrorTrue",
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
        // Shared between STORY-004 (original v2 backward-compat scenario) and
        // STORY-015 (additive v3 fields preserve all v2 keys + bump to v3).
        "Pre-existing fields remain unchanged for backward compatibility": [
            "AXNodeSerializerTests.test_serialize_includesAllPreExistingFields",
            "AXNodeSerializerTests.test_serialize_includesDescription_whenPresent",
            "AXNodeSerializerTests.test_serialize_includesStringValue_asString",
            "AXNodeSerializerTests.test_serialize_includesNumericValue_asNumber",
            "AXNodeSerializerTests.test_serializeRoot_includesSchemaVersion3_atTopLevel",
            "AXNodeSerializerTests.test_serializeRoot_keepsRootFieldsAtTopLevel_forBackwardCompatibility",
            "AXNodeSerializer_StateTests.test_serialize_preservesAllV2Fields_whenStateFieldsAdded",
            "AXNodeSerializer_StateTests.test_schemaVersion_isIncrementedTo3",
            "AXNodeSerializer_StateTests.test_serializeRoot_includesSchemaVersion3_atRoot",
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

        // MARK: STORY-014 — Find Elements by Query

        "Returns matching nodes by role and title substring": [
            "ElementPredicateTests.test_matches_byTitleContainsSubstring",
            "ElementPredicateTests.test_matches_requiresAllCriteriaToMatch",
            "FindElementsToolTests.test_execute_returnsMatchingButton_byRoleAndTitleContains",
            "FindElementsToolTests.test_execute_excludesNonMatchingSiblings",
        ],
        "Returns matching nodes by identifier exact match": [
            "ElementPredicateTests.test_matches_byExactIdentifier",
            "ElementPredicateTests.test_matches_rejectsDifferentIdentifier_whenExactSpecified",
            "ElementPredicateTests.test_matches_rejectsPartialIdentifier_whenExactSpecified",
            "FindElementsToolTests.test_execute_returnsOnlyExactIdentifierMatch",
        ],
        "Each result includes its AX path for disambiguation": [
            "AXPathBuilderTests.test_path_startsWithApplicationRole_andTitle",
            "AXPathBuilderTests.test_path_usesIdentifier_whenTitleAbsent",
            "AXPathBuilderTests.test_path_prefersTitle_overIdentifier_whenBothPresent",
            "AXPathBuilderTests.test_path_emitsEmptyDisambiguator_whenBothTitleAndIdentifierAbsent",
            "AXTreeWalkerTests.test_walk_capturesAncestorsForEachMatch",
            "FindElementsToolTests.test_execute_includesAXPath_withApplicationAndWindowAncestors",
        ],
        "Empty result for query with no matches is not an error": [
            "AXTreeWalkerTests.test_walk_returnsEmptyMatches_withoutTruncation_whenNothingMatches",
            "FindElementsToolTests.test_execute_returnsEmptyMatchesWithMetadata_whenNoMatch",
        ],
        "Hard cap on max_results prevents oversized payloads": [
            "AXTreeWalkerTests.test_walk_stopsAtMaxResults_andSetsTruncatedFlag",
            "AXTreeWalkerTests.test_walk_noTruncation_whenAllMatchesFitUnderCap",
            "AXTreeWalkerTests.test_walk_returnsShallowMatchesBeforeDeepMatches",
            "FindElementsToolTests.test_execute_truncatesAtMaxResults_andSetsFlagWithHint",
            "FindElementsToolTests.test_execute_clampsMaxResults_aboveHardLimit",
            "FindElementsToolTests.test_findElementsPayload_isFiveOrLess_percentOf_fullTreePayload",
        ],
        "Rejects predicates that would match every node": [
            "ElementPredicateTests.test_compile_throwsPredicateTooBroad_whenNoCriteriaSet",
            "FindElementsToolTests.test_execute_returnsPredicateTooBroad_withoutTouchingBridge",
        ],
        "Returns invalid_regex error when title_matches contains an invalid regex": [
            "ElementPredicateTests.test_compile_throwsInvalidRegex_withFieldName_whenTitleMatchesIsMalformed",
            "ElementPredicateTests.test_compile_throwsInvalidRegex_withFieldName_whenIdentifierMatchesIsMalformed",
            "FindElementsToolTests.test_execute_returnsInvalidRegex_withFieldName_andWithoutTouchingBridge",
        ],

        // MARK: STORY-015 — Extended Element State Attributes

        "Focused text field reports focused = true": [
            "AccessibilityTreeBuilderTests.test_build_propagatesFocused_fromBridge",
            "AXNodeSerializer_StateTests.test_serialize_focusedTrue_whenAXFocusedIsTrue",
            "AXNodeSerializer_StateTests.test_serialize_omitsFocused_whenAttributeUnsupported",
        ],
        "Selected list row reports selected = true": [
            "AccessibilityTreeBuilderTests.test_build_propagatesSelected_forAXRow",
            "AccessibilityTreeBuilderTests.test_build_skipsSelected_forAXButton",
            "AXNodeSerializer_StateTests.test_serialize_selected_forAXRow",
            "AXNodeSerializer_StateTests.test_serialize_omitsSelected_forNonSelectableRole",
        ],
        "Expanded disclosure triangle reports expanded = true": [
            "AccessibilityTreeBuilderTests.test_build_propagatesExpanded_forDisclosureTriangle",
            "AXNodeSerializer_StateTests.test_serialize_expanded_forAXDisclosureTriangle",
            "AXNodeSerializer_StateTests.test_serialize_expanded_falseForCollapsedDisclosure",
        ],
        "Off-screen elements report visible_in_viewport = false": [
            "ViewportVisibilityResolverTests.test_isVisible_returnsTrue_whenNodeFrameWithinWindow",
            "ViewportVisibilityResolverTests.test_isVisible_returnsFalse_whenNodeFrameOutsideWindow",
            "ViewportVisibilityResolverTests.test_isVisible_returnsTrue_forPartialClip",
            "ViewportVisibilityResolverTests.test_isVisible_returnsFalse_forZeroSizedNode",
            "ViewportVisibilityResolverTests.test_isVisible_returnsNil_whenContainingWindowFrameUnavailable",
            "ViewportVisibilityResolverTests.test_isVisible_returnsNil_whenNodeFrameUnavailable",
            "AccessibilityTreeBuilderTests.test_build_setsVisibleInViewport_true_whenChildIntersectsAncestorWindow",
            "AccessibilityTreeBuilderTests.test_build_setsVisibleInViewport_false_whenChildOutsideAncestorWindow",
            "AccessibilityTreeBuilderTests.test_build_omitsVisibleInViewport_onWindowRootItself",
            "AXNodeSerializer_StateTests.test_serialize_visibleInViewportTrue_whenSet",
            "AXNodeSerializer_StateTests.test_serialize_visibleInViewportFalse_whenSet",
            "AXNodeSerializer_StateTests.test_serialize_omitsVisibleInViewport_whenNil",
        ],
        "Window root node reports window-level state flags": [
            "AccessibilityTreeBuilderTests.test_build_setsWindowStateFlags_onAXWindowRoleOnly",
            "AccessibilityTreeBuilderTests.test_build_omitsWindowStateFlags_onNonWindowRoles",
            "AccessibilityTreeBuilderTests.test_build_setsIndependentWindowStateFlags_acrossSiblingWindows",
            "AXNodeSerializer_StateTests.test_serialize_windowStateFields_forAXWindowRole",
            "AXNodeSerializer_StateTests.test_serialize_skipsWindowStateFields_forNonWindowRoles",
        ],
        "New fields surface through element_at_position with the same shape": [
            "ElementAtPositionToolTests.test_execute_includesFocused_whenElementIsFocused",
            "ElementAtPositionToolTests.test_execute_responseIncludesSchemaVersion3",
            "AccessibilityTreeBuilderTests.test_buildShallow_setsFocusedSelectedExpanded",
            "AccessibilityTreeBuilderTests.test_buildShallow_omitsVisibleInViewport",
        ],
        // NOTE: "Pre-existing fields remain unchanged for backward compatibility"
        // is the title of both the STORY-004 and STORY-015 backward-compat
        // scenarios. The mapping for it lives in the STORY-004 block above and
        // covers proofs for both stories.

        // MARK: STORY-011 — MCP Tool Annotations and Descriptions

        "Read-only tools declare readOnlyHint = true": [
            "PerToolAnnotationMatrixTests.test_eachTool_hasExpectedAnnotation",
            "ToolCatalogAuditTests.test_accessibilityTree_descriptionMentionsReadOnlyBehavior",
        ],
        "Destructive tools declare destructiveHint = true": [
            "PerToolAnnotationMatrixTests.test_eachTool_hasExpectedAnnotation",
            "ToolCatalogAuditTests.test_runAppleScript_descriptionWarnsAboutSystemModification",
        ],
        "Every registered tool has annotations populated": [
            "ToolCatalogAuditTests.test_everyRegisteredTool_hasAnnotationsPopulated",
            "ToolCatalogAuditTests.test_everyTool_hasReadOnlyAndDestructiveHintsSet",
            "PerToolAnnotationMatrixTests.test_matrixCoversEveryRegisteredTool",
        ],
        "All tool descriptions meet the quality bar": [
            "ToolCatalogAuditTests.test_everyToolDescription_isAtLeast50Chars",
            "ToolCatalogAuditTests.test_everyToolDescription_hasNoPlaceholderText",
            "ToolCatalogAuditReportTests.test_writesCatalogAudit_andEveryToolPassesDoDChecks",
        ],
        "Tool schemas declare required vs optional parameters": [
            "ToolSchemaTests.testClickScreenRequiredParams",
            "ToolSchemaTests.testRunAppleScriptRequiredParams",
            "ToolSchemaTests.testTypeTextRequiredParams",
            "ToolSchemaTests.testWaitMillisecondsRequiredParams",
        ],
        "Enumerated parameter values are constrained in the schema": [
            "SchemaEnumAuditTests.test_clickScreen_buttonParam_declaresEnum",
            "SchemaEnumAuditTests.test_mouseDown_buttonParam_declaresEnum",
            "SchemaEnumAuditTests.test_mouseUp_buttonParam_declaresEnum",
            "SchemaEnumAuditTests.test_scroll_directionParam_declaresEnum",
            "SchemaEnumAuditTests.test_startContinuousCapture_captureType_declaresEnum",
            "SchemaEnumAuditTests.test_analyzeScreenNow_captureType_declaresEnum",
            "SchemaEnumAuditTests.test_startScreenMonitoring_captureType_declaresEnum",
            "SchemaEnumAuditTests.test_analyzeScreenWithLlm_captureType_declaresEnum",
            "SchemaEnumAuditTests.test_intelligentScreenSummary_captureType_declaresEnum",
            "SchemaEnumAuditTests.test_iphonePressKey_modifiersParam_declaresEnumViaItems",
        ],
        "idempotentHint is set for tools that are safe to retry": [
            "IdempotentHintTests.test_readOnlyTools_haveIdempotentHintTrue",
            "IdempotentHintTests.test_nonIdempotentTools_haveIdempotentHintFalse",
        ],
        "Correct annotation for each tool category": [
            "PerToolAnnotationMatrixTests.test_eachTool_hasExpectedAnnotation",
            "PerToolAnnotationMatrixTests.test_matrixCoversEveryRegisteredTool",
        ],

        // MARK: STORY-013 — MCP Resources for Ambient Context

        "Active application resource returns current frontmost app": [
            "ActiveApplicationResourceTests.test_read_returnsLocalizedName_bundleId_andPID",
            "ActiveApplicationResourceTests.test_read_includesLocalizedDisplayName",
            "MCPResourceCatalogTests.test_allResources_containsExpectedURIs",
            "MCPResourceCatalogTests.test_activeApplication_resourceHasJsonMime",
        ],
        "UI tree resource returns the current AX tree for the active window": [
            "ActiveWindowTreeResourceTests.test_read_returnsTreeForFrontmostApp_withSerializerSchema",
            "ActiveWindowTreeResourceTests.test_read_passesMaxDepthToBuilder",
            "MCPResourceCatalogTests.test_activeWindowTree_descriptionReferencesCurrentSchemaVersion",
            "MCPResourceCatalogTests.test_activeWindowTree_descriptionMentionsMaxDepthOverride",
            "ResourceURITests.test_parse_extractsMaxDepthQueryItem",
            "ResourceURITests.test_maxDepth_returnsDefault_whenQueryAbsent",
            "ResourceURITests.test_maxDepth_clampsBelowLowerBound",
            "ResourceURITests.test_maxDepth_clampsAboveUpperBound",
            "ResourceURITests.test_maxDepth_returnsDefault_whenValueNotAnInteger",
            "ResourceURITests.test_parse_extractsCanonicalURI_withoutQuery",
        ],
        "Resources update when the active application changes": [
            "ResourceSubscriptionRegistryTests.test_upstreamActivation_deliversUpdateToSubscribers",
            "ResourceSubscriptionRegistryTests.test_subscribe_installsObserver_onFirstSubscriber",
            "ResourceSubscriptionRegistryTests.test_rapidActivations_coalesce_toSingleDelivery",
        ],
        "Active-window-tree resource updates when the user switches windows within the same app": [
            "AXFocusedWindowSignalLifecycleTests.test_focusedWindowChange_firesHandler",
            "AXFocusedWindowSignalLifecycleTests.test_subscribe_installsAXSourceForCurrentFrontmostApp",
            "AXFocusedWindowSignalLifecycleTests.test_workspaceActivation_reTargetsAXSourceToNewPID",
            "AXFocusedWindowSignalLifecycleTests.test_workspaceActivation_doesNotReTarget_whenPIDUnchanged",
            "AXFocusedWindowSignalLifecycleTests.test_workspaceActivation_alsoFiresHandler",
            "AXFocusedWindowSignalLifecycleTests.test_remove_stopsAXSource_andDropsWorkspaceObserver",
            "AXFocusedWindowSignalLifecycleTests.test_remove_keepsAXSource_whileOtherSubscribersRemain",
            "CompositeEventLifecycleTests.test_addObserver_installsObserverOnEachUnderlyingSource",
            "CompositeEventLifecycleTests.test_handlerFires_whenAnyUnderlyingSourceFires",
            "CompositeEventLifecycleTests.test_remove_dropsObserverFromEachUnderlyingSource",
            "CompositeEventLifecycleTests.test_remove_isIdempotent",
            "ResourceSubscriptionRegistryTests.test_registerSignalSource_routesURIToOverrideLifecycle",
            "ResourceSubscriptionRegistryTests.test_unsubscribeWithOverride_removesFromOverrideLifecycle",
            "ResourceSubscriptionRegistryTests.test_eventOnOverrideLifecycle_deliversToSubscribers",
            "ActiveWindowTreeResourceTests.test_invalidateCache_forcesRebuildOnNextRead",
            "ActiveWindowTreeResourceTests.test_read_rebuildsTree_afterCacheExpires",
        ],
        "Resource read returns no_frontmost_application error when no app has focus": [
            "ActiveApplicationResourceTests.test_read_returnsNoFrontmostApplicationError_whenWorkspaceReturnsNil",
            "ActiveWindowTreeResourceTests.test_read_returnsNoFrontmostApplicationError_whenWorkspaceReturnsNil",
            "ResourceErrorsTests.test_noFrontmostApplication_hasExpectedErrorCode",
            "ResourceErrorsTests.test_noFrontmostApplication_descriptionIncludesErrorCode",
            "MCPResourceCatalogTests.test_activeApplication_descriptionMentionsErrorPath",
        ],
        "Resource read returns accessibility_permission_required error when AX permission is denied": [
            "ActiveWindowTreeResourceTests.test_read_returnsAccessibilityPermissionRequiredError_whenAXNotTrusted",
            "ResourceErrorsTests.test_accessibilityPermissionRequired_hasExpectedErrorCode",
            "ResourceErrorsTests.test_accessibilityPermissionRequired_descriptionExplainsHowToGrant",
        ],
        "Subscription unsubscribe stops further update notifications": [
            "ResourceSubscriptionRegistryTests.test_unsubscribe_stopsFurtherDeliveries",
            "ResourceSubscriptionRegistryTests.test_unsubscribe_removesUnderlyingObserver_whenLastSubscriberLeaves",
            "ResourceSubscriptionRegistryTests.test_unsubscribe_keepsObserver_whileOtherSubscribersRemain",
        ],
        "Concurrent subscribers each receive update notifications": [
            "ResourceSubscriptionRegistryTests.test_publish_deliversIdenticalContent_toAllSubscribers",
            "ResourceSubscriptionRegistryTests.test_subscribe_doesNotInstallExtraObserver_forSecondSubscriber",
        ],

        // MARK: STORY-016 — Structured Error Response Contract

        "Error response is structured JSON, not a free-text string": [
            "MCPErrorResponseBuilderTests.test_build_returnsResultWithIsErrorTrue",
            "MCPErrorResponseBuilderTests.test_build_emitsCodeMessageAndDetails_asWrappedJSON",
            "MCPErrorResponseBuilderTests.test_build_envelopeHasOkFalse",
            "MCPErrorResponseBuilderTests.test_build_omitsDetailsKey_whenDetailsNil",
            "MCPErrorResponseBuilderTests.test_build_omitsDetailsKey_whenDetailsEmpty",
        ],
        "Error codes follow snake_case convention": [
            "ErrorCodeRegistryTests.test_register_rejectsUppercaseCode",
            "ErrorCodeRegistryTests.test_register_rejectsCodeWithDash",
            "ErrorCodeRegistryTests.test_register_rejectsCodeStartingWithDigit",
            "ErrorCodeRegistryTests.test_register_rejectsEmptyCode",
            "ErrorCodeRegistryTests.test_register_acceptsValidSnakeCaseCode",
            "ErrorCodeRegistryTests.test_register_acceptsCodeAtMaxLength",
            "ErrorCodeRegistryTests.test_register_rejectsCodeLongerThan64Chars",
            "ErrorCodeBootstrapTests.test_bootstrap_codesAllValidSnakeCase",
        ],
        "Permission-denied error includes a recovery hint in details": [
            "PermissionDeniedDetailsTests.test_accessibilityPermissionRequired_includesRecoveryHintInDetails",
            "PermissionDeniedDetailsTests.test_accessibilityPermissionRequired_includesSystemSettingsURIInDetails",
            "PermissionDeniedDetailsTests.test_automationPermissionRequired_includesTargetApplicationInDetails",
            "ResourceErrorsTests.test_accessibilityPermissionRequired_detailsCarryRecoveryHintAndSettingsURI",
        ],
        "Coordinate-out-of-bounds error includes the valid bounds in details": [
            "ElementAtPositionToolTests.test_execute_rejectsCoords_outsideDisplayUnion",
            "ElementAtPositionToolTests.test_execute_doesNotInvokeBridge_whenOutOfBounds",
            "CoordinatesOutOfBoundsDetailsTests.test_outOfBounds_responseIncludesDisplayBoundsObjectInDetails",
        ],
        "Two tools cannot register the same error code with conflicting semantics": [
            "ErrorCodeRegistryTests.test_register_throwsCollisionError_whenCodeAlreadyRegistered",
            "ErrorCodeRegistryTests.test_collisionError_surfacesBothRegistrationCallSites",
            "ErrorCodeBootstrapTests.test_bootstrap_throwsCollision_whenCalledTwiceOnSameRegistry",
        ],
        "Unknown internal exception produces a generic structured error": [
            "MCPErrorResponseBuilderTests.test_buildFromUnknown_mapsArbitraryErrorToInternalError",
            "MCPErrorResponseBuilderTests.test_buildFromUnknown_doesNotLeakUserPaths",
            "MCPErrorResponseBuilderTests.test_buildFromUnknown_doesNotLeakPrivatePaths",
            "MCPErrorResponseBuilderTests.test_buildFromUnknown_setsIsErrorTrue",
        ],
        "Existing MCPError cases map to the new contract without behavioral change": [
            "MCPErrorMigrationTests.test_permissionDenied_mapsToSnakeCaseCode",
            "MCPErrorMigrationTests.test_windowNotFound_mapsToSnakeCaseCode",
            "MCPErrorMigrationTests.test_accessibilityPermissionRequired_mapsToSnakeCase_andCarriesDetails",
            "MCPErrorMigrationTests.test_everyMCPErrorCase_producesIsErrorTrueAndRegisteredSnakeCaseCode",
            "MCPErrorMigrationTests.test_descriptionFormat_isSnakeCaseColonMessage_notScreamingSnake",
            "NoAdhocErrorConstructionAuditTests.test_noAdhocErrorTextConstructionExists",
        ],
        "Unknown tool returns a structured error with isError = true": [
            "ToolRouterUnknownToolTests.test_unknownTool_returnsIsErrorTrue",
            "ToolRouterUnknownToolTests.test_unknownTool_returnsStructuredUnknownToolCode",
        ],

        // MARK: STORY-017 — MCP Prompts for Agent Workflows

        "Server lists registered prompts": [
            "PromptRegistryTests.test_list_includesAllThreeBundledPrompts",
            "PromptRegistryTests.test_list_eachPromptHasDescriptionAtLeast50Chars",
        ],
        "Client retrieves the interaction hierarchy prompt": [
            "PromptRegistryTests.test_get_interactionHierarchy_namesAllFourLayers",
            "PromptRegistryTests.test_get_interactionHierarchy_isUserRoleMessage",
        ],
        "Client retrieves the macOS permissions prompt": [
            "PromptRegistryTests.test_get_permissionsChecklist_describesAllThreePermissions",
        ],
        "Prompt with arguments substitutes them into the resolved content": [
            "PromptTemplateTests.test_resolve_substitutesNamedPlaceholder",
            "PromptTemplateTests.test_resolve_leavesNoUnsubstitutedPlaceholders",
            "PromptTemplateTests.test_resolve_handlesArgumentWithSpecialChars",
            "PromptRegistryTests.test_get_clickAndVerify_substitutesArguments",
        ],
        "Prompt request with missing required argument returns a structured error": [
            "PromptTemplateTests.test_resolve_throwsMissingRequiredArgument_whenRequiredArgAbsent",
            "PromptRegistryTests.test_get_throwsMissingRequiredArgument_whenArgumentAbsent",
        ],
        "Prompt request for an unknown name returns a structured error": [
            "PromptRegistryTests.test_get_throwsPromptNotFound_whenNameUnregistered",
        ],
        "Prompts are versioned and the version is exposed in metadata": [
            "PromptDefinitionTests.test_parse_loadsNameDescriptionAndPromptVersionFromFrontMatter",
            "PromptDefinitionTests.test_parse_throwsLoadTimeError_whenPromptVersionMissing",
            "PromptRegistryTests.test_list_eachPromptCarriesPromptVersionInMetadata",
        ],

        // MARK: STORY-008 — AXObserver Wait for UI Event Tool

        "Wait resolves when a window appears": [
            "AXObserverManagerTests.test_wait_returnsSuccess_whenNotificationFires",
            "AXObserverManagerTests.test_wait_dispatchesEachSupportedNotificationConstant",
            "WaitForUIEventToolTests.test_execute_returnsSchemaVersion3_inSuccessResponse",
            "WaitForUIEventToolTests.test_execute_passesNotificationAndPIDToManager",
        ],
        "Wait resolves when a sheet is dismissed": [
            "WaitForUIEventToolTests.test_execute_responseCarriesCachedAttributes_forDestroyedElement",
            "WaitForUIEventToolTests.test_execute_returnsElementNotFoundError_whenLocatorDoesNotResolve",
        ],
        "Wait times out if event does not occur within the specified duration": [
            "AXObserverManagerTests.test_wait_throwsWaitTimeoutError_whenDeadlineElapses",
            "AXObserverManagerTests.test_wait_doesNotLeakRunLoopSource_onTimeout",
            "WaitForUIEventToolTests.test_execute_translatesWaitTimeoutErrorFromManager",
        ],
        "Wait resolves when focused element changes": [
            "AXObserverManagerTests.test_wait_dispatchesEachSupportedNotificationConstant",
            "WaitForUIEventToolTests.test_execute_passesNotificationAndPIDToManager",
            "WaitForUIEventToolTests.test_execute_returnsSchemaVersion3_inSuccessResponse",
        ],
        "Observer is unregistered when the target application terminates mid-wait": [
            "AXObserverManagerTests.test_wait_throwsTargetTerminatedError_whenAppQuitsMidWait",
            "AXObserverManagerTests.test_wait_doesNotLeakObserver_onTermination",
            "WaitForUIEventToolTests.test_execute_translatesTargetTerminatedErrorFromManager",
        ],
        "Two concurrent waits on the same notification both resolve when it fires": [
            "AXObserverManagerTests.test_wait_multiplexesTwoCallers_ontoOneUnderlyingObserver",
            "AXObserverManagerTests.test_wait_unregistersObserver_afterLastWaiterResolves",
        ],
        "Permission denied at subscription time returns a structured error": [
            "AXObserverManagerTests.test_wait_throwsPermissionError_whenAXNotTrusted",
            "AXObserverManagerTests.test_canSubscribe_proxiesIsProcessTrusted",
            "WaitForUIEventToolTests.test_execute_returnsAccessibilityPermissionRequired_whenManagerCannotSubscribe",
        ],
        "Unsupported notification name returns a structured error": [
            "WaitForUIEventToolTests.test_execute_rejectsUnknownNotification_withSupportedList",
            "WaitForUIEventModuleTests.test_tool_inputSchema_constrainsNotificationToSupportedEnum",
        ],
        "Support the documented AX notification set": [
            "AXObserverManagerTests.test_wait_dispatchesEachSupportedNotificationConstant",
            "AXObserverManagerTests.test_wait_stressTest_noLeakedSubscriptionsAfter100SequentialTimeouts",
            "WaitForUIEventModuleTests.test_tool_description_namesEveryDoDListedNotification",
            "WaitForUIEventModuleTests.test_tool_inputSchema_constrainsNotificationToSupportedEnum",
        ],

        // MARK: STORY-009 — Element State Polling Tool

        "Wait resolves when a button becomes enabled": [
            "WaitForElementStateToolTests.test_execute_returnsSuccess_whenPredicateBecomesTrue",
            "ElementStatePollLoopTests.test_poll_returnsSatisfied_whenPredicateBecomesTrueOnNthPoll",
            "ConditionPredicateTests.test_booleanField_matchesOnlyWhenNodePropertyEqualsTarget",
        ],
        "Wait resolves when an element appears in the tree": [
            "WaitForElementStateToolTests.test_execute_returnsSuccess_whenElementAppears_existsTrue",
            "ConditionPredicateTests.test_exists_true_matchesWhenElementResolved",
        ],
        "Return timeout error if condition is not met": [
            "WaitForElementStateToolTests.test_execute_returnsStateConditionNotMetError_onTimeout",
            "ElementStatePollLoopTests.test_poll_returnsTimedOut_withLastStateAndCounts",
        ],
        "Wait resolves when an element becomes focused": [
            "WaitForElementStateToolTests.test_execute_handlesEveryStory015BooleanField",
            "ConditionPredicateTests.test_eachStory015Field_isReadFromItsOwnProperty",
        ],
        "Wait resolves when an element disappears from the tree": [
            "WaitForElementStateToolTests.test_execute_returnsSuccess_whenElementDisappears_existsFalse",
            "ElementStatePollLoopTests.test_poll_existsFalse_resolvesWhenElementDisappears",
            "ConditionPredicateTests.test_exists_false_matchesWhenElementGone",
        ],
        "Wait resolves when an element's value matches a target string": [
            "WaitForElementStateToolTests.test_execute_matchesStringValueEquality_caseSensitive",
            "ConditionPredicateTests.test_value_exactCaseSensitiveStringMatch",
            "ConditionExpressionParserTests.test_parse_acceptsValueStringEquality_singleAndDoubleQuotes",
        ],
        "Reject malformed condition expression": [
            "WaitForElementStateToolTests.test_execute_returnsInvalidConditionExpressionError_onMalformedInput",
            "ConditionExpressionParserTests.test_parse_rejectsDoubleEqualsChain",
            "ConditionExpressionParserTests.test_error_listsSupportedFieldsAndOperators",
        ],
        "Support every state field that the serializer emits": [
            "WaitForElementStateToolTests.test_execute_handlesEveryStory015BooleanField",
            "ConditionExpressionParserTests.test_parse_acceptsBooleanFields",
            "ConditionPredicateTests.test_eachStory015Field_isReadFromItsOwnProperty",
            "WaitForElementStateModuleTests.test_tool_description_namesEverySupportedField",
        ],

        // MARK: STORY-018 — Wait for Application Lifecycle Event Tool

        "Wait resolves when a named application launches": [
            "NSWorkspaceEventBridgeTests.test_wait_resolvesWhenLaunchNotificationFires",
            "WaitForAppEventToolTests.test_execute_returnsSuccessResponse_includingInteractionMethod",
            "WaitForAppEventToolTests.test_execute_passesEventAndFilterAndTimeoutToManager",
        ],
        "Wait resolves when an application becomes frontmost": [
            "NSWorkspaceEventBridgeTests.test_wait_dispatchesEachSupportedEventVariant",
            "NSWorkspaceEventBridgeTests.test_wait_activated_registersExactlyOneObserver_noDoubleSubscription",
        ],
        "Wait resolves when an application terminates": [
            "NSWorkspaceEventBridgeTests.test_wait_dispatchesEachSupportedEventVariant",
            "WaitForAppEventToolTests.test_execute_passesEventAndFilterAndTimeoutToManager",
        ],
        "Wait resolves on the next launch when no bundle_id filter is given": [
            "NSWorkspaceEventBridgeTests.test_wait_resolvesOnWildcard_whenBundleIdFilterIsNil",
            "WaitForAppEventToolTests.test_execute_wildcard_passesNilFilterToManager",
        ],
        "Wait times out if the lifecycle event never fires": [
            "NSWorkspaceEventBridgeTests.test_wait_throwsWaitTimeoutError_whenNoEventFires",
            "NSWorkspaceEventBridgeTests.test_wait_unregistersObserver_onTimeout",
            "NSWorkspaceEventBridgeTests.test_wait_stressTest_noLeakedObserversAfter100SequentialTimeouts",
            "WaitForAppEventToolTests.test_execute_translatesWaitTimeoutErrorFromManager",
        ],
        "Reject unsupported event name": [
            "WaitForAppEventToolTests.test_execute_rejectsUnsupportedEventName_withSupportedList",
            "WaitForAppEventModuleTests.test_tool_inputSchema_constrainsEventToSupportedEnum",
        ],
        "Reject malformed bundle identifier": [
            "WaitForAppEventToolTests.test_execute_rejectsMalformedBundleIdentifier",
            "BundleIdentifierValidatorTests.test_validate_rejectsSpaces",
            "BundleIdentifierValidatorTests.test_validate_rejectsInvalidChars",
        ],
        "Support every NSWorkspace lifecycle notification": [
            "NSWorkspaceEventBridgeTests.test_wait_dispatchesEachSupportedEventVariant",
            "WaitForAppEventModuleTests.test_tool_inputSchema_constrainsEventToSupportedEnum",
            "WaitForAppEventModuleTests.test_tool_description_namesEverySupportedEvent",
        ],

        // MARK: STORY-019 — Per-Application Capability Registry

        "Registry loads default entries at server startup": [
            "AppCapabilityRegistryTests.test_loadDefaults_returnsAtLeast20Entries",
            "AppCapabilityRegistryTests.test_loadDefaults_completesWithin200ms",
            "AppCapabilityRegistryTests.test_loadDefaults_recordsBooleanFlagsPerEntry",
            "AppCapabilityRegistryTests.test_defaults_shippedFile_hasAtLeast20Entries",
        ],
        "Lookup returns layer capabilities for a known bundle identifier": [
            "AppCapabilityRegistryTests.test_capabilities_returnsRegisteredEntry_forKnownBundleId",
        ],
        "Lookup returns \"unknown\" for unregistered bundle identifiers": [
            "AppCapabilityRegistryTests.test_capabilities_returnsUnknown_forUnregisteredBundleId",
        ],
        "User overrides shadow default entries": [
            "AppCapabilityRegistryTests.test_applyOverrides_userOverrideShadowsDefault",
            "AppCapabilityRegistryTests.test_applyOverrides_originalDefaultStillAccessibleViaDefaultEntry",
        ],
        "Reject malformed override file with a clear error": [
            "AppCapabilityRegistryTests.test_load_skipsMalformedOverrideEntries_andLogsStructuredError",
        ],
        "Registry exposes its contents via an MCP Resource": [
            "CapabilityRegistryResourceTests.test_resourceCatalog_includesCapabilityRegistry",
            "CapabilityRegistryResourceTests.test_read_returnsCompleteJsonDocument",
            "MCPResourceCatalogTests.test_allResources_containsExpectedURIs",
        ],
        "Capability fields are extensible without breaking existing consumers": [
            "AppCapabilityRegistryTests.test_decode_acceptsUnknownFutureFields_withoutError",
            "CapabilityRegistryResourceTests.test_read_reflectsSchemaVersionAndOverrideSource",
        ],
        "Known macOS apps have sensible default capabilities": [
            "AppCapabilityRegistryTests.test_defaults_match_Round7_outline_table",
        ],
    ]
}
