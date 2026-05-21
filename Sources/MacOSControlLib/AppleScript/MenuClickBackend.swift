import Foundation

/// Outcome of a single menu-click attempt as observed by the backend.
public enum ClickResult: Equatable {
    case success
    case disabled
    case notFound
}

/// Backend-neutral failure surface. Thrown by `MenuClickBackend` for failures
/// that don't translate to a `ClickResult` case (timeout, transport / I/O,
/// or otherwise unmapped backend error). Keeps `ClickMenuItemTool` decoupled
/// from any specific backend's error type — a future AX-direct backend will
/// throw the same cases.
public enum MenuClickError: Error, Equatable {
    case timeout(after: TimeInterval)
    case backendFailure(detail: String)
}

/// Abstracts the mechanism that turns a menu path + application into a
/// click. v1 is `AppleScriptMenuClickBackend`; a future AX-direct backend
/// can be swapped in without touching `ClickMenuItemTool` or its tests.
public protocol MenuClickBackend {
    func click(path: [String], application: String, doNotActivate: Bool) async throws -> ClickResult
    func alternatives(forFailingPath path: [String], application: String) async throws -> [String]
}

/// AppleScript-based concrete implementation. Composes a `MenuPathResolver`
/// (script generator) with an `AppleScriptExecuting` (osascript runner) and
/// emits an `AuditRecord` for every click and every alternatives lookup.
public final class AppleScriptMenuClickBackend: MenuClickBackend {

    public static let toolName = "click_menu_item"
    public static let clickTimeoutSeconds: TimeInterval = 30
    public static let alternativesTimeoutSeconds: TimeInterval = 10

    private let executor: AppleScriptExecuting
    private let resolver: MenuPathResolving
    private let audit: AuditRecording

    public init(executor: AppleScriptExecuting,
                resolver: MenuPathResolving,
                audit: AuditRecording) {
        self.executor = executor
        self.resolver = resolver
        self.audit = audit
    }

    public func click(path: [String], application: String, doNotActivate: Bool) async throws -> ClickResult {
        let script = resolver.script(for: path, application: application, doNotActivate: doNotActivate)
        let sha = ScriptHasher.sha256Hex(script)

        let result = try await executor.run(script, timeout: Self.clickTimeoutSeconds)
        switch result {
        case .success(_, let durationMs, _):
            audit.record(AuditRecordDraft(
                eventType: .menuClick,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .success,
                durationMs: durationMs
            ))
            return .success

        case .failure(.scriptError(let code, let message)):
            audit.record(AuditRecordDraft(
                eventType: .menuClick,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .scriptError,
                durationMs: 0,
                scriptErrorCode: code
            ))
            if message.range(of: "is disabled", options: .caseInsensitive) != nil {
                return .disabled
            }
            return .notFound

        case .failure(.timeout(let after)):
            audit.record(AuditRecordDraft(
                eventType: .menuClick,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .timeout,
                durationMs: Int((after * 1000).rounded())
            ))
            throw MenuClickError.timeout(after: after)

        case .failure(.ioError(let detail)):
            audit.record(AuditRecordDraft(
                eventType: .menuClick,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .ioError,
                durationMs: 0
            ))
            throw MenuClickError.backendFailure(detail: detail)

        case .failure(.cancelled):
            // STORY-027 — click_menu_item is not on the cancellable surface
            // (Q4: quick tools support cancellation uniformly but rarely use it).
            // If it ever observes a cancelled result it surfaces as a backend
            // failure with a cancelled audit outcome so the chain stays
            // consistent. throw CancellationError so the SDK suppresses the
            // response.
            audit.record(AuditRecordDraft(
                eventType: .menuClick,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .cancelled,
                durationMs: 0
            ))
            throw CancellationError()
        }
    }

    public func alternatives(forFailingPath path: [String], application: String) async throws -> [String] {
        let script = resolver.alternativesScript(for: path, application: application)
        let sha = ScriptHasher.sha256Hex(script)

        let result = try await executor.run(script, timeout: Self.alternativesTimeoutSeconds)
        switch result {
        case .success(let stdout, let durationMs, _):
            audit.record(AuditRecordDraft(
                eventType: .menuAlternativesLookup,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .success,
                durationMs: durationMs
            ))
            return parseAlternatives(stdout)

        case .failure(.scriptError(let code, _)):
            audit.record(AuditRecordDraft(
                eventType: .menuAlternativesLookup,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .scriptError,
                durationMs: 0,
                scriptErrorCode: code
            ))
            return []

        case .failure(.timeout(let after)):
            audit.record(AuditRecordDraft(
                eventType: .menuAlternativesLookup,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .timeout,
                durationMs: Int((after * 1000).rounded())
            ))
            return []

        case .failure(.ioError):
            audit.record(AuditRecordDraft(
                eventType: .menuAlternativesLookup,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .ioError,
                durationMs: 0
            ))
            return []

        case .failure(.cancelled):
            audit.record(AuditRecordDraft(
                eventType: .menuAlternativesLookup,
                scriptSha256: sha,
                targetApps: [application],
                filterDisposition: .allowed,
                executionOutcome: .cancelled,
                durationMs: 0
            ))
            throw CancellationError()
        }
    }

    private func parseAlternatives(_ stdout: String) -> [String] {
        stdout
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }
}
