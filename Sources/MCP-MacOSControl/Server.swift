import Foundation
import MCP
import MacOSControlLib

@main
enum MacOSControlServer {
    static func main() async throws {
        // STORY-016: trigger lazy bootstrap of the error-code registry so a
        // bootstrap failure surfaces immediately (via fatalError inside the
        // singleton) rather than on the first tool call. Then log the contract
        // change so operators tailing stderr see it on every cold start.
        let registeredCount = MacOSControlLib.ErrorCodeRegistry.shared.allRegistrations().count
        MacOSControlLib.MCPLogger.info("Error responses now structured JSON; legacy text format removed (STORY-016). \(registeredCount) codes registered.")

        // STORY-024 — Audit subsystem bootstrap.
        //
        // Load configuration; fail-fast on invalid env-var combinations
        // (per BDD §2 "Server refuses to start when audit config is
        // internally inconsistent"). Then construct the persistent
        // AuditRecorder, the chain verifier, and the retention sweeper;
        // verify the existing chain on disk before serving any tool
        // calls. A verification failure at startup is reported as a
        // SECURITY-CRITICAL log line — the server still starts (to
        // preserve availability) but the operator is expected to
        // investigate immediately.
        let auditConfig = MacOSControlLib.AuditConfig.load()
        do {
            try auditConfig.validate()
        } catch {
            fputs("Audit configuration invalid: \(error)\n", stderr)
            exit(1)
        }
        let auditIdentity = MacOSControlLib.AuditInstallIdentityResolver.resolve(config: auditConfig)
        let auditStorage: MacOSControlLib.AuditStorage
        do {
            auditStorage = try MacOSControlLib.FileAuditStorage(logDirectory: auditConfig.logDirectory)
        } catch {
            fputs("Failed to open audit log directory \(auditConfig.logDirectory.path): \(error)\n", stderr)
            exit(1)
        }
        let auditSink = MacOSControlLib.AuditRemoteSinkFactory.make(config: auditConfig)
        let auditRecorder = MacOSControlLib.AuditRecorder(
            storage: auditStorage,
            remoteSink: auditSink,
            config: auditConfig,
            identity: auditIdentity
        )
        let auditVerifier = MacOSControlLib.AuditChainVerifier(
            storage: auditStorage, identity: auditIdentity
        )
        let auditSweeper = MacOSControlLib.AuditRetentionSweeper(
            storage: auditStorage,
            verifier: auditVerifier,
            clock: MacOSControlLib.SystemClock(),
            retentionDays: auditConfig.retentionDays
        )
        let startupReport = auditVerifier.verify()
        if !startupReport.isValid {
            MacOSControlLib.MCPLogger.error(
                "SECURITY-CRITICAL: audit chain verification failed on startup — \(startupReport.summary)"
            )
        } else {
            MacOSControlLib.MCPLogger.info(
                "STORY-024 audit subsystem ready: \(startupReport.totalChecked) records verified, sink=\(auditConfig.remoteSinkKind.rawValue), retention=\(auditConfig.retentionDays)d."
            )
        }
        // Swap the in-process auditor used by run_applescript /
        // click_menu_item, and wire the admin tools.
        MacOSControlLib.AppleScriptModule.auditor = auditRecorder
        MacOSControlLib.AuditAdminModule.wiring = MacOSControlLib.AuditAdminModule.Wiring(
            auditor: auditRecorder,
            sweeper: auditSweeper,
            verifier: auditVerifier,
            adminEnabled: auditConfig.adminToolsEnabled
        )

        // Start the background maintenance loops: retry pending
        // records (BDD: outage recovery flushes in order) and daily
        // retention sweep (DoD: AuditRetentionSweeper runs daily).
        let auditMaintenance = MacOSControlLib.AuditMaintenanceLoop(
            storage: auditStorage,
            remoteSink: auditSink,
            sweeper: auditSweeper,
            config: auditConfig
        )
        auditMaintenance.start()

        // STORY-019: load the per-app capability registry. Bundled defaults are
        // required infrastructure — a missing/malformed default file is fatal
        // (same posture as the prompt registry below). A malformed *user
        // override* is non-fatal: load() logs a structured error and continues
        // with defaults only.
        let capabilityRegistry = AppCapabilityRegistry.standardRegistry()
        do {
            try capabilityRegistry.load()
            MacOSControlLib.MCPLogger.info("Per-app capability registry loaded: \(capabilityRegistry.allEntries.count) entries (STORY-019).")
        } catch {
            fputs("Failed to load default app-capabilities registry: \(error)\n", stderr)
            exit(1)
        }
        let capabilityResource = CapabilityRegistryResource(registry: capabilityRegistry)

        let server = Server(
            name: "mcp-macos-control",
            version: "1.0.0",
            instructions: """
                MCP-MacOSControl: 65 tools for macOS and iPhone automation, plus ambient-context Resources.

                COORDINATE SYSTEMS:
                - macOS tools (click_screen, move_mouse, etc.): absolute pixel coordinates
                - iPhone tools (iphone_tap, iphone_swipe, etc.): normalized 0.0-1.0 where (0,0)=top-left, (1,1)=bottom-right

                KEY PATTERNS:

                1. macOS interaction: Use take_screenshot_with_ocr or accessibility_tree to find elements, then click_screen/type_text to interact.

                2. iPhone interaction (observe-reason-act loop):
                   a. iphone_screenshot_with_ocr to see current screen and get text coordinates
                   b. Identify target element from OCR results
                   c. iphone_tap at the element's normalized coordinates (use OCR coords directly)
                   d. iphone_wait_for_text to confirm the action took effect before next step

                3. Opening an iPhone app: Use iphone_open_app (handles Spotlight sequence automatically).

                4. Waiting for UI transitions: Use wait_for_text (macOS) or iphone_wait_for_text (iPhone) instead of fixed delays. These poll OCR until specific text appears.

                5. Accessibility tree: Use accessibility_tree for macOS app UI structure (role, label, position). Does NOT work for iPhone Mirroring content.

                6. Ambient context Resources: subscribe to macos://ui/active-application or macos://ui/active-window-tree for change notifications without invoking accessibility_tree on every turn.

                TOOL CATEGORIES:
                - Mouse (9): click_screen, double_click, move_mouse, mouse_down/up, drag_mouse, scroll, get_screen_size, list_displays
                - Keyboard (4): type_text, press_keys, key_down, key_up
                - Screen (2): take_screenshot, take_screenshot_with_ocr
                - Windows (2): list_windows, activate_window
                - System (3): check_permissions, wait_milliseconds, wait_for_text
                - Accessibility (1): accessibility_tree
                - iPhone Mirroring (21): iphone_launch, iphone_tap, iphone_swipe, iphone_type_text, iphone_screenshot_with_ocr, iphone_open_app, iphone_wait_for_text, and more
                - Vision (5), CoreML (8), Realtime (4), Continuous Capture (6)
                """,
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: true, listChanged: false),
                tools: .init(listChanged: true)
            )
        )

        // Resource wiring (STORY-013).
        let workspaceProvider = NSWorkspaceProvider()
        let permissionChecker = SystemAccessibilityPermissionChecker()
        let axBridge = AXApplicationBridgeImpl()
        let treeBuilder = AccessibilityTreeBuilder(bridge: axBridge)
        let serializer = AXNodeSerializer()
        let appResource = ActiveApplicationResource(workspace: workspaceProvider)
        let treeResource = ActiveWindowTreeResource(
            workspace: workspaceProvider,
            permission: permissionChecker,
            builder: treeBuilder,
            serializer: serializer
        )
        // active-application listens to NSWorkspace app-activation only.
        // active-window-tree composes NSWorkspace + AX focused-window
        // changes so within-app window switches also trigger updates.
        let nsWorkspaceLifecycle = NSWorkspaceObserverLifecycle()
        let focusedWindowLifecycle = AXFocusedWindowSignalLifecycle(
            workspaceLifecycle: NSWorkspaceObserverLifecycle(),
            workspaceProvider: workspaceProvider,
            sourceFactory: AXFocusedWindowSourceFactoryImpl()
        )
        let treeSignalSource = CompositeEventLifecycle([nsWorkspaceLifecycle, focusedWindowLifecycle])

        let registry = ResourceSubscriptionRegistry(
            observerLifecycle: nsWorkspaceLifecycle,
            publishSink: { uri, _ in
                Task { try? await server.notify(ResourceUpdatedNotification.message(.init(uri: uri))) }
            }
        )
        // The notification payload is just the URI per MCP spec — content
        // delivery happens via a subsequent `resources/read`. Both producers
        // return an empty placeholder; the sink ignores the content.
        registry.registerContentProducer(ResourceURIs.activeApplication) {
            ["uri": ResourceURIs.activeApplication]
        }
        registry.registerContentProducer(ResourceURIs.activeWindowTree) { [weak treeResource] in
            treeResource?.invalidateCache()
            return ["uri": ResourceURIs.activeWindowTree]
        }
        registry.registerSignalSource(ResourceURIs.activeWindowTree, treeSignalSource)

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: ToolRouter.allTools)
        }

        // STORY-027 — in-flight registry maps server-generated request ids to
        // their CancellationToken so SIGTERM can drain in-flight work uniformly.
        // The swift-sdk already routes `notifications/cancelled` into
        // `Task.cancel()` on the handler task; the `withTaskCancellationHandler`
        // below bridges that signal into the token so non-Task waiters (AX
        // continuations, NSWorkspace observers, osascript subprocesses, polling
        // loops) can tear down their resources.
        let inFlightRegistry = MacOSControlLib.InFlightRegistry()
        await server.withMethodHandler(CallTool.self) { params in
            let requestId = UUID().uuidString
            let token = MacOSControlLib.CancellationToken()
            await inFlightRegistry.register(requestId: requestId, token: token)
            defer {
                Task { await inFlightRegistry.finish(requestId: requestId) }
            }
            return try await withTaskCancellationHandler {
                let context = MacOSControlLib.ToolCallContext(
                    requestId: requestId,
                    cancellation: token
                )
                return try await ToolRouter.handle(params, context: context)
            } onCancel: {
                token.cancel()
            }
        }

        // Prompt wiring (STORY-017). Built once at startup; loading errors are
        // fatal — a missing prompt file means the binary is mis-bundled and we
        // would rather refuse to start than serve a half-empty catalog.
        let promptRegistry: PromptRegistry
        do {
            promptRegistry = try PromptRegistry.standardRegistry()
        } catch {
            fputs("Failed to load bundled prompt definitions: \(error)\n", stderr)
            exit(1)
        }

        await server.withMethodHandler(ListPrompts.self) { _ in
            .init(prompts: promptRegistry.list())
        }

        await server.withMethodHandler(GetPrompt.self) { params in
            do {
                return try promptRegistry.get(name: params.name, arguments: params.arguments ?? [:])
            } catch let error as PromptError {
                // Mirror the resources/read error pattern (Server.swift below):
                // wrap the structured error in a {ok:false, error:{...}} envelope
                // and return it as the prompt's single message so agents can parse
                // it uniformly across tools, resources, and prompts.
                var errorObject: [String: Any] = [
                    "code": error.code,
                    "message": error.message
                ]
                if let details = error.details, !details.isEmpty {
                    errorObject["details"] = details
                }
                let envelope: [String: Any] = [
                    "ok": false,
                    "error": errorObject
                ]
                let data = (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data()
                let text = String(data: data, encoding: .utf8) ?? "{}"
                return .init(
                    description: "error: \(error.code)",
                    messages: [.user(.text(text: text))]
                )
            }
        }

        await server.withMethodHandler(ListResources.self) { _ in
            .init(resources: MCPResourceCatalog.allResources)
        }

        await server.withMethodHandler(ReadResource.self) { params in
            let parsed = ResourceURIParser.parse(params.uri)
            do {
                let payload: [String: Any]
                switch parsed.canonicalURI {
                case ResourceURIs.activeApplication:
                    payload = try appResource.read()
                case ResourceURIs.activeWindowTree:
                    payload = try treeResource.read(maxDepth: parsed.maxDepth())
                case ResourceURIs.capabilityRegistryContents:
                    payload = capabilityResource.read()
                default:
                    throw MacOSControlLib.MCPError.windowNotFound("Unknown resource URI: \(params.uri)")
                }
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
                let text = String(data: data, encoding: .utf8) ?? "{}"
                return .init(contents: [
                    .text(text, uri: params.uri, mimeType: "application/json")
                ])
            } catch let error as MacOSControlLib.MCPError {
                // STORY-016: resources/read errors use the same wrapped JSON
                // shape as tool errors so agents can parse both uniformly.
                var errorObject: [String: Any] = [
                    "code": error.errorCode,
                    "message": error.message
                ]
                if let details = error.details, !details.isEmpty {
                    errorObject["details"] = details
                }
                let envelope: [String: Any] = [
                    "ok": false,
                    "error": errorObject
                ]
                let data = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
                let text = String(data: data, encoding: .utf8) ?? "{}"
                return .init(contents: [
                    .text(text, uri: params.uri, mimeType: "application/json")
                ])
            }
        }

        await server.withMethodHandler(ResourceSubscribe.self) { params in
            let canonical = ResourceURIParser.parse(params.uri).canonicalURI
            registry.subscribe(canonical, clientId: "stdio") { _ in }
            return Empty()
        }

        await server.withMethodHandler(ResourceUnsubscribe.self) { params in
            let canonical = ResourceURIParser.parse(params.uri).canonicalURI
            registry.unsubscribe(canonical, clientId: "stdio")
            return Empty()
        }

        // STORY-027 — graceful SIGTERM. Drain in-flight tool calls via the
        // registry (each token's onCancel hooks send SIGTERM to osascript
        // subprocesses, unregister AX/NSWorkspace observers, exit polling
        // loops) and then exit. The 2.5s wait gives the tool-side budgets
        // (per-tool max 1500ms) room to complete tear-down before exit(0).
        // SIG_IGN is required so DispatchSource sees the signal — without it
        // the default handler kills the process before we ever run.
        signal(SIGTERM, SIG_IGN)
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
        sigtermSource.setEventHandler {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                await inFlightRegistry.cancelAll()
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 2.5)
            exit(0)
        }
        sigtermSource.resume()

        let transport = StdioTransport()
        do {
            try await server.start(transport: transport)
            await server.waitUntilCompleted()
        } catch {
            fputs("Error starting server: \(error)\n", stderr)
            exit(1)
        }
    }
}
