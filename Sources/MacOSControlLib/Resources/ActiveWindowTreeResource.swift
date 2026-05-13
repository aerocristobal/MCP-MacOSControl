import Foundation

/// Builds the AX tree for the frontmost application's active window. Composes
/// `AccessibilityTreeBuilder` + `AXNodeSerializer` so the per-node shape is
/// identical to `accessibility_tree` (and inherits any STORY-015 / future
/// schema bumps automatically — single source of truth in the serializer).
///
/// Caches the serialized payload for `cacheTTL` after each read keyed by
/// `(pid, maxDepth)` so a polling client triggers at most one AX walk per
/// window per 100ms.
public final class ActiveWindowTreeResource {

    public static let defaultCacheTTL: TimeInterval = 0.1

    private struct CacheEntry {
        let pid: pid_t
        let maxDepth: Int
        let timestamp: Date
        let payload: [String: Any]
    }

    private let workspace: WorkspaceProvider
    private let permission: AccessibilityPermissionChecker
    private let builder: AccessibilityTreeBuilder
    private let serializer: AXNodeSerializer
    private let dateProvider: DateProviding
    private let cacheTTL: TimeInterval
    private var cache: CacheEntry?
    private let lock = NSLock()

    public init(
        workspace: WorkspaceProvider,
        permission: AccessibilityPermissionChecker,
        builder: AccessibilityTreeBuilder,
        serializer: AXNodeSerializer,
        dateProvider: DateProviding = SystemDateProvider(),
        cacheTTL: TimeInterval = ActiveWindowTreeResource.defaultCacheTTL
    ) {
        self.workspace = workspace
        self.permission = permission
        self.builder = builder
        self.serializer = serializer
        self.dateProvider = dateProvider
        self.cacheTTL = cacheTTL
    }

    public func read(maxDepth: Int = 6) throws -> [String: Any] {
        guard permission.isProcessTrusted() else {
            throw MCPError.accessibilityPermissionRequired
        }
        guard let info = workspace.frontmostApplication else {
            throw MCPError.noFrontmostApplication
        }
        let pid = info.processIdentifier
        let now = dateProvider.now()

        lock.lock()
        if let entry = cache,
           entry.pid == pid,
           entry.maxDepth == maxDepth,
           now.timeIntervalSince(entry.timestamp) < cacheTTL {
            lock.unlock()
            return entry.payload
        }
        lock.unlock()

        let root = try builder.build(forPID: pid, windowTitle: nil, maxDepth: maxDepth)
        let payload = serializer.serializeRoot(root)

        lock.lock()
        cache = CacheEntry(pid: pid, maxDepth: maxDepth, timestamp: now, payload: payload)
        lock.unlock()

        return payload
    }

    /// Drop the cache; called by the subscription registry when a window-switch
    /// notification fires so the next read returns fresh data.
    public func invalidateCache() {
        lock.lock(); defer { lock.unlock() }
        cache = nil
    }
}
