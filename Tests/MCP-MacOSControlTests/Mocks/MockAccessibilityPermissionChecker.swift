import Foundation
@testable import MacOSControlLib

final class MockAccessibilityPermissionChecker: AccessibilityPermissionChecker {
    var trusted: Bool = true
    func isProcessTrusted() -> Bool { trusted }
}
