import Foundation
import AppKit

/// Lightweight descriptor for the frontmost macOS application. Decouples
/// resource code from `NSRunningApplication` so tests can substitute fixed
/// values without instantiating real running-application objects.
public struct FrontmostApplicationInfo: Equatable, Sendable {
    public let localizedName: String?
    public let bundleIdentifier: String?
    public let processIdentifier: pid_t

    public init(localizedName: String?, bundleIdentifier: String?, processIdentifier: pid_t) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }
}

/// Wraps `NSWorkspace.shared.frontmostApplication` so the active-application
/// resource can be tested without depending on which real app happens to have
/// focus on the test runner.
public protocol WorkspaceProvider: AnyObject {
    var frontmostApplication: FrontmostApplicationInfo? { get }
}

public final class NSWorkspaceProvider: WorkspaceProvider {
    public init() {}

    public var frontmostApplication: FrontmostApplicationInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FrontmostApplicationInfo(
            localizedName: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier
        )
    }
}
