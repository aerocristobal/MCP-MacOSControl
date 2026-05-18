// STORY: STORY-018 — Wait for Application Lifecycle Event Tool
// COMPONENT: WaitForAppEventTool (MCP tool surface)

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForAppEventToolTests: XCTestCase {

    var manager: FakeNSWorkspaceEventManaging!
    var tool: WaitForAppEventTool!

    override func setUp() {
        super.setUp()
        manager = FakeNSWorkspaceEventManaging()
        tool = WaitForAppEventTool(manager: manager)
    }

    private func parseJSON(_ text: String) throws -> [String: Any] {
        let data = text.data(using: .utf8) ?? Data()
        return try (JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Input validation

    func test_execute_rejectsMissingEvent() async throws {
        let result = await tool.execute(makeParams(name: "wait_for_app_event", args: [:]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "invalid_input")
        XCTAssertEqual(manager.waitCallCount, 0)
    }

    func test_execute_rejectsUnsupportedEventName_withSupportedList() async throws {
        let result = await tool.execute(makeParams(name: "wait_for_app_event", args: [
            "event": .string("hibernated")
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "unsupported_app_event")
        let details = error["details"] as? [String: Any] ?? [:]
        let supported = details["supported_events"] as? [String] ?? []
        XCTAssertTrue(supported.contains("launched"),
                      "supported_events must enumerate the closed set")
        XCTAssertEqual(manager.waitCallCount, 0,
                       "unsupported event must short-circuit before reaching the manager")
    }

    func test_execute_rejectsMalformedBundleIdentifier() async throws {
        let result = await tool.execute(makeParams(name: "wait_for_app_event", args: [
            "event": .string("launched"),
            "bundle_identifier": .string("not a bundle id")
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "invalid_bundle_identifier")
        XCTAssertEqual(manager.waitCallCount, 0)
    }

    func test_execute_rejectsTimeoutAboveCap() async throws {
        let result = await tool.execute(makeParams(name: "wait_for_app_event", args: [
            "event": .string("launched"),
            "timeout_seconds": .double(600)
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "timeout_exceeds_maximum")
        XCTAssertEqual(manager.waitCallCount, 0)
    }

    // MARK: - Happy path

    func test_execute_returnsSuccessResponse_includingInteractionMethod() async throws {
        manager.stubbedEvent = AppLifecycleEvent(
            eventType: .launched,
            bundleIdentifier: "com.apple.calculator",
            pid: 4321,
            localizedName: "Calculator")
        let result = await tool.execute(makeParams(name: "wait_for_app_event", args: [
            "event": .string("launched"),
            "bundle_identifier": .string("com.apple.calculator")
        ]))
        XCTAssertFalse(result.isError ?? false)

        let json = try parseJSON(extractText(from: result) ?? "")
        XCTAssertEqual(json["event_type"] as? String, "launched")
        XCTAssertEqual(json["bundle_identifier"] as? String, "com.apple.calculator")
        XCTAssertEqual(json["pid"] as? Int, 4321)
        XCTAssertEqual(json["localized_name"] as? String, "Calculator")
        XCTAssertEqual(json["interaction_method"] as? String, "nsworkspace_observer")
        XCTAssertNotNil(json["elapsed_seconds"])
    }

    func test_execute_passesEventAndFilterAndTimeoutToManager() async throws {
        manager.stubbedEvent = AppLifecycleEvent(
            eventType: .terminated, bundleIdentifier: "com.apple.TextEdit",
            pid: 1, localizedName: "TextEdit")
        _ = await tool.execute(makeParams(name: "wait_for_app_event", args: [
            "event": .string("terminated"),
            "bundle_identifier": .string("com.apple.TextEdit"),
            "timeout_seconds": .double(12)
        ]))
        XCTAssertEqual(manager.lastEvent, .terminated)
        XCTAssertEqual(manager.lastBundleIdentifierFilter, "com.apple.TextEdit")
        XCTAssertEqual(manager.lastTimeout, 12)
    }

    func test_execute_appliesDefaultTimeout_whenOmitted() async throws {
        _ = await tool.execute(makeParams(name: "wait_for_app_event", args: [
            "event": .string("activated"),
            "bundle_identifier": .string("com.apple.TextEdit")
        ]))
        XCTAssertEqual(manager.lastTimeout, WaitForAppEventTool.defaultTimeoutSeconds)
    }

    func test_execute_wildcard_passesNilFilterToManager() async throws {
        _ = await tool.execute(makeParams(name: "wait_for_app_event", args: [
            "event": .string("launched")
        ]))
        XCTAssertEqual(manager.waitCallCount, 1)
        XCTAssertTrue(manager.lastFilterWasNil,
                      "omitting bundle_identifier must reach the manager with a nil wildcard filter")
    }

    // MARK: - Error translation

    func test_execute_translatesWaitTimeoutErrorFromManager() async throws {
        manager.stubbedError = AppEventWaitTimeoutError(
            event: "launched", bundleIdentifierFilter: "com.apple.calculator", elapsedSeconds: 2.0)
        let result = await tool.execute(makeParams(name: "wait_for_app_event", args: [
            "event": .string("launched"),
            "bundle_identifier": .string("com.apple.calculator"),
            "timeout_seconds": .double(2)
        ]))
        XCTAssertEqual(result.isError, true)
        let error = try result.parseStructuredError()
        XCTAssertEqual(error["code"] as? String, "wait_timeout")
        let details = error["details"] as? [String: Any] ?? [:]
        XCTAssertEqual(details["event"] as? String, "launched")
        XCTAssertEqual(details["bundle_id_filter"] as? String, "com.apple.calculator")
    }
}
