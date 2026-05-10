// STORY-007 — click_menu_item MCP Tool
// COMPONENT: AppleScriptMenuClickBackend (v1 implementation of MenuClickBackend)

import XCTest
@testable import MacOSControlLib

final class AppleScriptMenuClickBackendTests: XCTestCase {

    var executorSpy: AppleScriptExecutorSpy!
    var resolverSpy: MenuPathResolverSpy!
    var auditSpy: AuditRecorderSpy!
    var backend: AppleScriptMenuClickBackend!

    override func setUp() {
        super.setUp()
        executorSpy = AppleScriptExecutorSpy()
        resolverSpy = MenuPathResolverSpy()
        auditSpy = AuditRecorderSpy()
        backend = AppleScriptMenuClickBackend(executor: executorSpy,
                                              resolver: resolverSpy,
                                              audit: auditSpy)
    }

    // MARK: - click(...)

    func test_click_invokesResolverThenExecutor() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 5)
        resolverSpy.stubbedScript = "tell application \"System Events\" to ..."

        _ = try await backend.click(path: ["File", "Save"],
                                    application: "TextEdit",
                                    doNotActivate: false)

        XCTAssertEqual(resolverSpy.lastPath, ["File", "Save"])
        XCTAssertEqual(resolverSpy.lastApplication, "TextEdit")
        XCTAssertEqual(executorSpy.runCallCount, 1)
        XCTAssertEqual(executorSpy.lastScript, "tell application \"System Events\" to ...")
    }

    func test_click_returnsSuccess_whenExecutorSucceeds() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 5)

        let result = try await backend.click(path: ["File", "Save"],
                                             application: "TextEdit",
                                             doNotActivate: false)

        XCTAssertEqual(result, .success)
    }

    func test_click_mapsDisabledErrorFromOsascriptStderr() async throws {
        executorSpy.stubbedResult = .failure(.scriptError(
            code: -1728,
            message: "Can't get menu item \"Cut\". (item is disabled)"))

        let result = try await backend.click(path: ["Edit", "Cut"],
                                             application: "TextEdit",
                                             doNotActivate: false)

        XCTAssertEqual(result, .disabled)
    }

    func test_click_mapsNotFoundErrorFromOsascriptStderr() async throws {
        executorSpy.stubbedResult = .failure(.scriptError(
            code: -1728,
            message: "Can't get menu item \"Ghost\"."))

        let result = try await backend.click(path: ["File", "Ghost"],
                                             application: "TextEdit",
                                             doNotActivate: false)

        XCTAssertEqual(result, .notFound)
    }

    func test_click_propagatesDoNotActivateFlagToResolver() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 5)

        _ = try await backend.click(path: ["File", "Save"],
                                    application: "TextEdit",
                                    doNotActivate: true)

        XCTAssertEqual(resolverSpy.lastDoNotActivate, true)
    }

    func test_click_emitsAuditRecord_perInvocation() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 7)

        _ = try await backend.click(path: ["File", "Save"],
                                    application: "TextEdit",
                                    doNotActivate: false)

        XCTAssertEqual(auditSpy.records.count, 1)
        let record = auditSpy.records[0]
        XCTAssertEqual(record.toolName, "click_menu_item")
        XCTAssertEqual(record.outcome, .success)
        XCTAssertEqual(record.durationMs, 7)
        XCTAssertEqual(record.targetApps, ["TextEdit"])
        XCTAssertFalse(record.scriptSha256.isEmpty)
    }

    func test_click_emitsAuditWithScriptErrorOutcome_whenExecutorFails() async throws {
        executorSpy.stubbedResult = .failure(.scriptError(code: -1728,
                                                          message: "Can't get menu item \"Ghost\"."))

        _ = try await backend.click(path: ["File", "Ghost"],
                                    application: "TextEdit",
                                    doNotActivate: false)

        XCTAssertEqual(auditSpy.records.count, 1)
        XCTAssertEqual(auditSpy.records[0].outcome, .scriptError(code: -1728))
    }

    func test_click_throwsBackendNeutralTimeout_whenExecutorTimesOut() async {
        executorSpy.stubbedResult = .failure(.timeout(after: 30))

        do {
            _ = try await backend.click(path: ["File", "Save"],
                                        application: "TextEdit",
                                        doNotActivate: false)
            XCTFail("expected backend to throw on timeout")
        } catch let error as MenuClickError {
            XCTAssertEqual(error, .timeout(after: 30))
        } catch {
            XCTFail("expected MenuClickError, got \(type(of: error))")
        }

        XCTAssertEqual(auditSpy.records.count, 1)
        XCTAssertEqual(auditSpy.records[0].outcome, .timeout)
    }

    func test_click_throwsBackendNeutralFailure_whenExecutorIOErrors() async {
        executorSpy.stubbedResult = .failure(.ioError("could not launch"))

        do {
            _ = try await backend.click(path: ["File", "Save"],
                                        application: "TextEdit",
                                        doNotActivate: false)
            XCTFail("expected backend to throw on I/O error")
        } catch let error as MenuClickError {
            XCTAssertEqual(error, .backendFailure(detail: "could not launch"))
        } catch {
            XCTFail("expected MenuClickError, got \(type(of: error))")
        }
    }

    // MARK: - alternatives(...)

    func test_alternatives_invokesResolverAlternativesScript() async throws {
        executorSpy.stubbedResult = .success(stdout: "New, Open, Save, Save As, Print",
                                             durationMs: 3)
        resolverSpy.stubbedAlternativesScript = "tell application \"System Events\" to get name of every menu item ..."

        let alternatives = try await backend.alternatives(forFailingPath: ["File", "Ghost"],
                                                          application: "TextEdit")

        // Sorted alphabetically per resolved Open Question 4.
        XCTAssertEqual(alternatives, ["New", "Open", "Print", "Save", "Save As"])
        XCTAssertEqual(resolverSpy.lastAlternativesPath, ["File", "Ghost"])
        XCTAssertEqual(resolverSpy.lastAlternativesApplication, "TextEdit")
    }

    func test_alternatives_returnsEmptyArray_whenExecutorFails() async throws {
        executorSpy.stubbedResult = .failure(.scriptError(code: -1700, message: "boom"))

        let alternatives = try await backend.alternatives(forFailingPath: ["File", "Ghost"],
                                                          application: "TextEdit")

        XCTAssertEqual(alternatives, [])
    }

    func test_alternatives_emitsAuditRecord_perInvocation() async throws {
        executorSpy.stubbedResult = .success(stdout: "New, Open", durationMs: 2)

        _ = try await backend.alternatives(forFailingPath: ["File", "Ghost"],
                                           application: "TextEdit")

        XCTAssertEqual(auditSpy.records.count, 1)
        XCTAssertEqual(auditSpy.records[0].toolName, "click_menu_item")
    }
}
