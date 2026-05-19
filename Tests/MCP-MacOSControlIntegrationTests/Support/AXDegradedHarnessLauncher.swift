// STORY-012 — End-to-End Integration Validation Suite
// COMPONENT: Launches the version-controlled AX-degraded SwiftUI harness.
//
// The harness is an SPM `.executableTarget`; SwiftPM builds it next to the
// xctest bundle. On launch it writes its window's click point (CoreGraphics
// top-left origin) to the file named by AXDEGRADED_HARNESS_FRAME_FILE, so tests
// can drive the coordinate-fallback layer deterministically without reading the
// (intentionally empty) AX tree.

import Foundation
import XCTest
import CoreGraphics

struct LaunchedHarness {
    let process: Process
    let clickPoint: CGPoint
    let frameFile: URL

    init(process: Process, clickPoint: CGPoint, frameFile: URL) {
        self.process = process
        self.clickPoint = clickPoint
        self.frameFile = frameFile
    }

    func terminate() {
        if process.isRunning { process.terminate() }
        try? FileManager.default.removeItem(at: frameFile)
    }

    /// The frame file is written ~0.4s after the window appears; the launcher
    /// already blocked on it, so this is a no-op kept for call-site clarity.
    func waitUntilReady() async throws {}
}

enum AXDegradedHarnessLauncher {

    /// SwiftPM bare-executable localized name — what NSRunningApplication and
    /// the smart_interact `application` scope see.
    static let processName = "AXDegradedHarness"

    enum LaunchError: Error, CustomStringConvertible {
        case binaryNotFound(searched: [String])
        case neverReportedFrame
        var description: String {
            switch self {
            case .binaryNotFound(let s): return "AXDegradedHarness binary not found. Searched: \(s)"
            case .neverReportedFrame:    return "AXDegradedHarness never wrote its frame file"
            }
        }
    }

    static func launch() throws -> LaunchedHarness {
        let binary = try locateBinary()
        let frameFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("axdegraded-frame-\(UUID().uuidString).json")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        var env = ProcessInfo.processInfo.environment
        env["AXDEGRADED_HARNESS_FRAME_FILE"] = frameFile.path
        process.environment = env
        try process.run()

        // Block until the harness reports its window geometry (max ~6s).
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline {
            if let data = try? Data(contentsOf: frameFile),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let x = obj["x"] as? Double, let y = obj["y"] as? Double {
                return LaunchedHarness(
                    process: process,
                    clickPoint: CGPoint(x: x, y: y),
                    frameFile: frameFile)
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
        process.terminate()
        throw LaunchError.neverReportedFrame
    }

    /// Resolve the built executable: explicit env override, else alongside the
    /// xctest bundle (SwiftPM places target binaries in the same products dir).
    private static func locateBinary() throws -> String {
        var searched: [String] = []

        if let override = ProcessInfo.processInfo.environment["AXDEGRADED_HARNESS_BIN"],
           !override.isEmpty {
            searched.append(override)
            if FileManager.default.isExecutableFile(atPath: override) { return override }
        }

        let bundleDir = Bundle(for: BundleAnchor.self).bundleURL.deletingLastPathComponent()
        // products dir, and one level up (…/debug or …/release).
        for dir in [bundleDir, bundleDir.deletingLastPathComponent()] {
            let candidate = dir.appendingPathComponent(processName).path
            searched.append(candidate)
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        throw LaunchError.binaryNotFound(searched: searched)
    }

    private final class BundleAnchor {}
}
