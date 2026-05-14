import Foundation
@testable import MacOSControlLib

final class MockWorkspaceProvider: WorkspaceProvider {
    var frontmostApplication: FrontmostApplicationInfo?
}
