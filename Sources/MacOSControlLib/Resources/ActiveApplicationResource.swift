import Foundation

/// Resolves the current frontmost application and produces the JSON content
/// for `macos://ui/active-application`.
public final class ActiveApplicationResource {
    private let workspace: WorkspaceProvider

    public init(workspace: WorkspaceProvider) {
        self.workspace = workspace
    }

    public func read() throws -> [String: Any] {
        guard let info = workspace.frontmostApplication else {
            throw MCPError.noFrontmostApplication
        }
        var dict: [String: Any] = [
            "pid": Int(info.processIdentifier)
        ]
        if let name = info.localizedName {
            dict["name"] = name
            dict["display_name"] = name
        }
        if let bundleId = info.bundleIdentifier {
            dict["bundle_identifier"] = bundleId
        }
        return dict
    }
}
