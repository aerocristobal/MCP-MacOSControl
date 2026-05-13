import Foundation
import ApplicationServices

/// Indirection over `AXIsProcessTrusted()` so the tree resource can simulate
/// permission-denied without poking the real TCC state.
public protocol AccessibilityPermissionChecker: AnyObject {
    func isProcessTrusted() -> Bool
}

public final class SystemAccessibilityPermissionChecker: AccessibilityPermissionChecker {
    public init() {}
    public func isProcessTrusted() -> Bool { AXIsProcessTrusted() }
}
