import Foundation
import AppKit
import ApplicationServices
import MCP

public final class FindElementsTool {
    public typealias PIDResolver = (_ application: String?) -> pid_t?

    private let bridge: AXApplicationBridge
    private let treeBuilder: AccessibilityTreeBuilder
    private let serializer: AXNodeSerializer
    private let permissionsChecker: () -> Bool
    private let pidResolver: PIDResolver

    public init(
        bridge: AXApplicationBridge,
        treeBuilder: AccessibilityTreeBuilder? = nil,
        serializer: AXNodeSerializer = AXNodeSerializer(),
        permissionsChecker: @escaping () -> Bool = { AXIsProcessTrusted() },
        pidResolver: PIDResolver? = nil
    ) {
        self.bridge = bridge
        self.treeBuilder = treeBuilder ?? AccessibilityTreeBuilder(bridge: bridge)
        self.serializer = serializer
        self.permissionsChecker = permissionsChecker
        self.pidResolver = pidResolver ?? Self.defaultPIDResolver
    }

    public func execute(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]

        let input = FindElementsInput(
            role:               args["role"]?.stringValue,
            title:              args["title"]?.stringValue,
            titleContains:      args["title_contains"]?.stringValue,
            titleMatches:       args["title_matches"]?.stringValue,
            identifier:         args["identifier"]?.stringValue,
            identifierMatches:  args["identifier_matches"]?.stringValue,
            label:              args["label"]?.stringValue,
            description:        args["description"]?.stringValue
        )
        let application = args["application"]?.stringValue
        let windowTitle = args["window_title"]?.stringValue
        let maxResults = clampedMaxResults(args["max_results"]?.intValue)
        let maxDepth = max(0, args["max_depth"]?.intValue ?? 12)

        // 1. Compile predicate first — errors here MUST NOT touch the AX C-API.
        let predicate: ElementPredicate
        do {
            predicate = try ElementPredicate.compile(from: input)
        } catch let err as FindElementsError {
            return errorResult(code: err.code, message: err.message)
        } catch {
            return errorResult(code: "predicate_compile_failed", message: error.localizedDescription)
        }

        // 2. Permission gate.
        guard permissionsChecker() else {
            return errorResult(
                code: "permission_denied",
                message: "Accessibility permission required. Go to System Settings > Privacy & Security > Accessibility."
            )
        }

        // 3. Resolve target PID.
        guard let pid = pidResolver(application) else {
            return errorResult(
                code: "application_not_found",
                message: "Application '\(application ?? "frontmost")' not found"
            )
        }

        // 4. Resolve start element (window or app root).
        let root: AXElementReference
        do {
            root = try resolveRoot(pid: pid, windowTitle: windowTitle)
        } catch let err as MCPError {
            return errorResult(code: err.errorCode.lowercased(), message: String(describing: err))
        } catch {
            return errorResult(code: "ax_resolution_failed", message: error.localizedDescription)
        }

        // 5. Walk + time.
        let walker = AXTreeWalker(bridge: bridge)
        let start = DispatchTime.now()
        let walkResult = walker.walk(
            from: root,
            matching: predicate,
            maxDepth: maxDepth,
            maxResults: maxResults
        )
        let elapsedNs = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        let elapsedMs = Int(elapsedNs / 1_000_000)

        // 6. Serialize matches with ax_path.
        let matchPayloads: [[String: Any]] = walkResult.matches.map { match in
            let node = treeBuilder.buildShallow(from: match.reference)
            var dict = serializer.serialize(node)
            dict["ax_path"] = AXPathBuilder.path(ancestors: match.ancestors, target: match.reference)
            return dict
        }

        var response: [String: Any] = [
            "schema_version": AXNodeSerializer.schemaVersion,
            "matches": matchPayloads,
            "scanned_node_count": walkResult.scannedNodeCount,
            "elapsed_ms": elapsedMs,
            "truncated_results": walkResult.truncatedResults
        ]
        if walkResult.truncatedResults {
            response["note"] = "predicate matched additional nodes beyond max_results=\(maxResults); raise max_results or narrow the predicate to see more"
        }

        let text = jsonString(response) ?? "{}"
        return .init(content: [.text(text)], isError: false)
    }

    // MARK: - Helpers

    private func resolveRoot(pid: pid_t, windowTitle: String?) throws -> AXElementReference {
        if let windowTitle, !windowTitle.isEmpty {
            let windows = try bridge.windows(forPID: pid)
            for window in windows {
                if let title = bridge.attribute(.title, of: window),
                   title.localizedCaseInsensitiveContains(windowTitle) {
                    return window
                }
            }
            throw MCPError.windowNotFound("Window titled '\(windowTitle)' not found for pid \(pid)")
        }
        guard let root = bridge.applicationRoot(forPID: pid) else {
            throw MCPError.windowNotFound("Application root unavailable for pid \(pid)")
        }
        return root
    }

    private func clampedMaxResults(_ raw: Int?) -> Int {
        let v = raw ?? 50
        return max(1, min(500, v))
    }

    private func errorResult(code: String, message: String) -> CallTool.Result {
        .init(content: [.text("\(code): \(message)")], isError: true)
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Default production PID resolver

    private static let defaultPIDResolver: PIDResolver = { application in
        let workspace = NSWorkspace.shared
        if let application = application, !application.isEmpty {
            let isBundleId = application.contains(".")
            for app in workspace.runningApplications {
                if isBundleId, app.bundleIdentifier == application {
                    return app.processIdentifier
                }
                if !isBundleId, app.localizedName?.localizedCaseInsensitiveContains(application) == true {
                    return app.processIdentifier
                }
            }
            return nil
        }
        return workspace.frontmostApplication?.processIdentifier
    }
}
