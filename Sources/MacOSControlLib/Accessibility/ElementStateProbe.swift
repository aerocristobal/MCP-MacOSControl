import Foundation

/// STORY-009 — the outcome of a single poll cycle: either the element resolved
/// (carrying its freshly serialized `AXNode` state) or it was not found in the
/// tree this cycle. "Not found" is a first-class, non-error state — the `exists`
/// predicate is the deliberate way to wait for appearance/disappearance, and
/// (Q2) a not-yet-present element waits the full timeout rather than failing.
public enum ElementProbeResult {
    case matched(AXNode)
    case notFound
}

/// Seam between the pure poll loop and the real AX tree read. Production wiring
/// resolves the locator and builds the element's `AXNode`; tests inject a
/// scripted sequence of results.
public protocol ElementStateProbe: AnyObject {
    func probe() async -> ElementProbeResult
}

/// Element locator — the same shape as `click_element` / `wait_for_ui_event`.
public struct ElementLocator: Sendable {
    public var role: String?
    public var title: String?
    public var identifier: String?
    public var label: String?
    public var description: String?

    public init(
        role: String? = nil,
        title: String? = nil,
        identifier: String? = nil,
        label: String? = nil,
        description: String? = nil
    ) {
        self.role = role
        self.title = title
        self.identifier = identifier
        self.label = label
        self.description = description
    }

    public var hasAny: Bool {
        role != nil || title != nil || identifier != nil || label != nil || description != nil
    }
}

/// Production probe: re-resolves the locator every poll and builds a single
/// `AXNode` for it.
///
/// Hybrid `visible_in_viewport` (STORY-009 design decision): `buildShallow` is
/// deliberately viewport-blind — a single-node read has no ancestor window to
/// measure against. Only when the caller's condition is `visible_in_viewport`
/// does the probe build the element's containing-window subtree (which computes
/// the field) and locate the resolved node within it. Every other field uses
/// the cheap shallow path.
public final class AXElementStateProbe: ElementStateProbe {

    /// Depth used for the heavier viewport build. Generous enough to reach
    /// deeply nested controls; only paid for `visible_in_viewport` conditions.
    private static let viewportBuildMaxDepth = 25

    private let resolver: AXElementResolving
    private let treeBuilder: AccessibilityTreeBuilder
    private let locator: ElementLocator
    private let pid: pid_t
    private let needsViewport: Bool

    public init(
        resolver: AXElementResolving,
        treeBuilder: AccessibilityTreeBuilder,
        locator: ElementLocator,
        pid: pid_t,
        needsViewport: Bool
    ) {
        self.resolver = resolver
        self.treeBuilder = treeBuilder
        self.locator = locator
        self.pid = pid
        self.needsViewport = needsViewport
    }

    public func probe() async -> ElementProbeResult {
        let ref: AXElementReference
        do {
            ref = try resolveLocator()
        } catch {
            // Not found this cycle (or a transient resolution failure). Either
            // way the loop keeps waiting — presence is tested via `exists`.
            return .notFound
        }

        if needsViewport, let node = viewportNode(for: ref) {
            return .matched(node)
        }
        return .matched(treeBuilder.buildShallow(from: ref))
    }

    // MARK: - Locator resolution (precedence mirrors wait_for_ui_event)

    private func resolveLocator() throws -> AXElementReference {
        let scope: AXResolverScope = .pid(pid)
        if let id = locator.identifier {
            return try resolver.findElement(by: .identifier, value: id, scope: scope)
        }
        if locator.title != nil || locator.role != nil {
            return try resolver.findElement(role: locator.role, title: locator.title, scope: scope)
        }
        if let label = locator.label {
            return try resolver.findElement(by: .label, value: label, scope: scope)
        }
        if let description = locator.description {
            return try resolver.findElement(by: .description, value: description, scope: scope)
        }
        throw AXNotFoundError(searchCriteria: "(no locators)")
    }

    // MARK: - Hybrid viewport build

    private func viewportNode(for ref: AXElementReference) -> AXNode? {
        guard let root = try? treeBuilder.build(
            forPID: pid,
            windowTitle: nil,
            maxDepth: Self.viewportBuildMaxDepth
        ) else { return nil }
        return locate(ref, in: root)
    }

    /// Best-effort match of the resolved reference within a freshly built tree:
    /// prefer the accessibility identifier, then role+title.
    private func locate(_ ref: AXElementReference, in node: AXNode) -> AXNode? {
        if matches(ref, node) { return node }
        for child in node.children {
            if let hit = locate(ref, in: child) { return hit }
        }
        return nil
    }

    private func matches(_ ref: AXElementReference, _ node: AXNode) -> Bool {
        if let id = ref.identifier, !id.isEmpty {
            return node.identifier == id
        }
        return node.role == ref.role && node.title == ref.title
    }
}
