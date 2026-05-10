import Foundation
import AppKit
#if canImport(ApplicationServices)
import ApplicationServices
#endif

public enum AutomationPermissionResult: Equatable {
    case granted
    case denied(targetApp: String)
    case skipped
}

public protocol AutomationPermissionChecking {
    func extractTargetApps(from script: String) -> [String]
    func check(targetApps: [String]) -> AutomationPermissionResult
}

public final class AutomationPermissionChecker: AutomationPermissionChecking {

    public init() {}

    /// Statically extract `tell application "Name"` clauses from script source.
    /// Best-effort per resolved Open Question 5 — dynamic name construction is
    /// not detected and yields `.skipped` from `check(targetApps:)`.
    public func extractTargetApps(from script: String) -> [String] {
        let pattern = #"(?i)tell\s+application\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(script.startIndex..., in: script)
        let matches = regex.matches(in: script, options: [], range: range)

        var seen = Set<String>()
        var ordered: [String] = []
        for match in matches where match.numberOfRanges >= 2 {
            if let r = Range(match.range(at: 1), in: script) {
                let name = String(script[r])
                if !seen.contains(name) {
                    seen.insert(name)
                    ordered.append(name)
                }
            }
        }
        return ordered
    }

    public func check(targetApps: [String]) -> AutomationPermissionResult {
        guard !targetApps.isEmpty else { return .skipped }
        for app in targetApps {
            switch checkSingle(app: app) {
            case .denied(let denied):
                return .denied(targetApp: denied)
            case .granted, .skipped:
                continue
            }
        }
        return .granted
    }

    /// Call AEDeterminePermissionToAutomateTarget for a single target app. The
    /// API is soft-deprecated by Apple but still functional under macOS 13+ and
    /// is mandated by the resolved Open Question 5.
    private func checkSingle(app: String) -> AutomationPermissionResult {
        guard let bundleID = bundleID(forAppName: app) else {
            // App is not running and we can't resolve a bundle ID — treat as
            // skipped so osascript itself surfaces the error.
            return .skipped
        }

        var targetDesc = AEAddressDesc()
        let bundleData = Data(bundleID.utf8)
        let createStatus: OSErr = bundleData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> OSErr in
            guard let base = raw.baseAddress else { return OSErr(errAEEventNotHandled) }
            return AECreateDesc(
                DescType(typeApplicationBundleID),
                base,
                bundleData.count,
                &targetDesc
            )
        }

        guard createStatus == noErr else {
            return .skipped
        }
        defer { AEDisposeDesc(&targetDesc) }

        let status = AEDeterminePermissionToAutomateTarget(
            &targetDesc,
            DescType(typeWildCard),
            DescType(typeWildCard),
            true  // askUserIfNeeded — surfaces the TCC prompt path explicitly
        )

        switch Int(status) {
        case Int(noErr):
            return .granted
        case Int(errAEEventNotPermitted),
             -1744:  // errAEEventNotPermitted spelled out for clarity
            return .denied(targetApp: app)
        default:
            // Procnotfound and friends — let osascript surface the actual error.
            return .skipped
        }
    }

    private func bundleID(forAppName name: String) -> String? {
        if name.contains(".") {
            return name
        }
        let running = NSWorkspace.shared.runningApplications
        if let match = running.first(where: {
            ($0.localizedName ?? "").localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return match.bundleIdentifier
        }
        return nil
    }
}
