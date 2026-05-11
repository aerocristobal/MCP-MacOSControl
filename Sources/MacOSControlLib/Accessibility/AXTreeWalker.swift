import Foundation

public struct AXTreeWalkerMatch {
    public let reference: AXElementReference
    public let ancestors: [AXElementReference]
}

public struct AXTreeWalkerResult {
    public let matches: [AXTreeWalkerMatch]
    public let scannedNodeCount: Int
    public let truncatedResults: Bool
}

/// Breadth-first walker over the AX tree. BFS lets `maxResults` surface shallow
/// matches first (a Save button in a toolbar wins over the same-titled button
/// buried 5 levels deep inside a sheet). Stops at the first of:
///   * `maxResults` matches collected (sets `truncatedResults` if more remain in queue);
///   * `maxDepth` exceeded (does not descend deeper);
///   * the queue is drained.
public final class AXTreeWalker {

    private let bridge: AXApplicationBridge

    public init(bridge: AXApplicationBridge) {
        self.bridge = bridge
    }

    public func walk(
        from root: AXElementReference,
        matching predicate: ElementPredicate,
        maxDepth: Int,
        maxResults: Int
    ) -> AXTreeWalkerResult {
        struct Frame {
            let ref: AXElementReference
            let ancestors: [AXElementReference]
            let depth: Int
        }

        var queue: [Frame] = [Frame(ref: root, ancestors: [], depth: 0)]
        var matches: [AXTreeWalkerMatch] = []
        var scanned = 0

        while let frame = queue.first, matches.count < maxResults {
            queue.removeFirst()
            scanned += 1

            if predicate.matches(frame.ref) {
                matches.append(AXTreeWalkerMatch(reference: frame.ref, ancestors: frame.ancestors))
                if matches.count >= maxResults { break }
            }

            if frame.depth < maxDepth {
                let children = (try? bridge.children(of: frame.ref)) ?? []
                let nextAncestors = frame.ancestors + [frame.ref]
                for child in children {
                    queue.append(Frame(ref: child, ancestors: nextAncestors, depth: frame.depth + 1))
                }
            }
        }

        let truncated = matches.count >= maxResults && !queue.isEmpty
        return AXTreeWalkerResult(
            matches: matches,
            scannedNodeCount: scanned,
            truncatedResults: truncated
        )
    }
}
