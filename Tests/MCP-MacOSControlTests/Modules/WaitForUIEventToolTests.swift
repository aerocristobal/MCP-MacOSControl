// STORY: STORY-008 — AXObserver Wait for UI Event Tool
// COMPONENT: WaitForUIEventTool (MCP tool surface)

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForUIEventToolTests: XCTestCase {

    var manager: FakeAXObserverManager!
    var resolver: AXElementResolverSpy!
    var tool: WaitForUIEventTool!
    let testPID: pid_t = 4242

    override func setUp() {
        super.setUp()
        manager = FakeAXObserverManager()
        resolver = AXElementResolverSpy()
        tool = WaitForUIEventTool(
            manager: manager,
            resolver: resolver,
            pidResolver: { _ in (self.testPID, "com.apple.TextEdit") }
        )
    }

    private func parseJSON(_ text: String) throws -> [String: Any] {
        let data = text.data(using: .utf8) ?? Data()
        return try (JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Input validation

    func test_execute_rejectsMissingNotification() async throws {
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "invalid_input")
    }

    func test_execute_rejectsMissingApplication() async throws {
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated")
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "invalid_input")
    }

    func test_execute_rejectsUnknownNotification_withSupportedList() async throws {
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXMadeUpNotification"),
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "unsupported_notification")

        let details = error["details"] as? [String: Any] ?? [:]
        let supported = details["supported_notifications"] as? [String] ?? []
        XCTAssertTrue(supported.contains("AXWindowCreated"),
                      "supported_notifications must enumerate the closed set")
        XCTAssertEqual(manager.waitCallCount, 0,
                       "unsupported notification must short-circuit before reaching the manager")
    }

    func test_execute_rejectsTimeoutAboveCap() async throws {
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("TextEdit"),
            "timeout_seconds": .double(600)
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "timeout_exceeds_maximum")
        XCTAssertEqual(manager.waitCallCount, 0)
    }

    // MARK: - Permission gate

    func test_execute_returnsAccessibilityPermissionRequired_whenManagerCannotSubscribe() async throws {
        manager.stubbedCanSubscribe = false
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "accessibility_permission_required")
        XCTAssertEqual(manager.waitCallCount, 0,
                       "permission gate must precede subscription")
    }

    // MARK: - Application resolution

    func test_execute_returnsApplicationNotFound_whenPIDResolverReturnsNil() async throws {
        tool = WaitForUIEventTool(
            manager: manager,
            resolver: resolver,
            pidResolver: { _ in nil }
        )
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("NonexistentApp")
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "application_not_found")
    }

    // MARK: - Happy path

    func test_execute_returnsSchemaVersion3_inSuccessResponse() async throws {
        manager.stubbedEvent = WaitForUIEvent(
            notification: "AXWindowCreated",
            elementRole: "AXWindow",
            elementTitle: "Untitled"
        )
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("TextEdit")
        ]))
        XCTAssertFalse(result.isError ?? false)

        let text = extractText(from: result) ?? ""
        let json = try parseJSON(text)
        XCTAssertEqual(json["schema_version"] as? Int, AXNodeSerializer.schemaVersion)
        XCTAssertEqual(json["interaction_method"] as? String, "ax_observer")
        XCTAssertEqual(json["notification"] as? String, "AXWindowCreated")
    }

    func test_execute_passesNotificationAndPIDToManager() async throws {
        manager.stubbedEvent = WaitForUIEvent(notification: "AXFocusedUIElementChanged")
        _ = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXFocusedUIElementChanged"),
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(manager.lastNotification, "AXFocusedUIElementChanged")
        XCTAssertEqual(manager.lastPID, testPID)
    }

    func test_execute_appliesDefaultTimeout_whenOmitted() async throws {
        manager.stubbedEvent = WaitForUIEvent(notification: "AXWindowCreated")
        _ = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(manager.lastTimeout, WaitForUIEventTool.defaultTimeoutSeconds)
    }

    // MARK: - Element-locator path

    func test_execute_returnsElementNotFoundError_whenLocatorDoesNotResolve() async throws {
        resolver.stubbedError = AXNotFoundError(searchCriteria: "role=AXSheet")
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXUIElementDestroyed"),
            "application": .string("TextEdit"),
            "element_locator": .object([
                "role": .string("AXSheet")
            ])
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "element_not_found")
        XCTAssertEqual(manager.waitCallCount, 0,
                       "element_not_found must short-circuit before the manager subscribes")
    }

    func test_execute_responseCarriesCachedAttributes_forDestroyedElement() async throws {
        resolver.stubbedResult = AXElementReference.mockReference(
            role: "AXSheet",
            title: "Save changes?",
            identifier: "save-changes-sheet"
        )
        manager.stubbedEvent = WaitForUIEvent(notification: "AXUIElementDestroyed")
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXUIElementDestroyed"),
            "application": .string("TextEdit"),
            "element_locator": .object([
                "role": .string("AXSheet")
            ])
        ]))
        XCTAssertFalse(result.isError ?? false)

        let text = extractText(from: result) ?? ""
        let json = try parseJSON(text)
        let element = json["element"] as? [String: Any] ?? [:]
        XCTAssertEqual(element["identifier"] as? String, "save-changes-sheet",
                       "destroyed-element responses must surface the cached identifier (Q6)")
        XCTAssertEqual(element["role"] as? String, "AXSheet")
    }

    // MARK: - Error translation

    func test_execute_translatesWaitTimeoutErrorFromManager() async throws {
        manager.stubbedError = WaitTimeoutError(notification: "AXWindowCreated", elapsedSeconds: 3.0)
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("TextEdit"),
            "timeout_seconds": .double(3)
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "wait_timeout")
        let details = error["details"] as? [String: Any] ?? [:]
        XCTAssertEqual(details["notification"] as? String, "AXWindowCreated")
    }

    func test_execute_translatesTargetTerminatedErrorFromManager() async throws {
        manager.stubbedError = TargetApplicationTerminatedError(
            pid: testPID,
            bundleIdentifier: "com.apple.TextEdit"
        )
        let result = await tool.execute(makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXValueChanged"),
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "target_application_terminated")
        let details = error["details"] as? [String: Any] ?? [:]
        XCTAssertEqual(details["bundle_identifier"] as? String, "com.apple.TextEdit")
    }
}
