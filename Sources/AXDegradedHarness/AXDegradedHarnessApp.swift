// STORY-012 — End-to-End Integration Validation Suite
//
// A deliberately accessibility-degraded SwiftUI app. Its single "Action" button
// is marked `.accessibilityHidden(true)`, so the AX tree exposes no semantic
// control for it. smart_interact's `ax_semantic` layer therefore fails to
// resolve the target and the router falls through to a later layer — exactly
// the failure-recovery path SmartInteractFallbackTests exercises.
//
// Why a first-party harness instead of a real Electron app: reproducibility.
// Slack 4.x and 5.x have different AX trees; tests against a moving third-party
// target are flaky and inscrutable when they fail. This target is
// version-controlled and intentional.
//
// On launch the app writes its content button's global screen rect (CoreGraphics
// top-left origin, suitable for the coordinate layer) as JSON to the path in the
// `AXDEGRADED_HARNESS_FRAME_FILE` environment variable, so the integration test
// can drive the coordinate fallback deterministically without reading the AX
// tree (which is intentionally empty here).

import SwiftUI
import AppKit

@main
struct AXDegradedHarnessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("AX Degraded Harness") {
            ContentView()
                .frame(width: 320, height: 200)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("AX Degraded Harness")
                .font(.headline)
                .accessibilityHidden(true)
            Button("Action") {
                // No-op: the integration test only needs the click to land,
                // not a side effect. Side effects are verified elsewhere.
            }
            .accessibilityHidden(true)
            .accessibilityIdentifier("")
        }
        .padding(24)
        // The whole content tree is hidden from accessibility so neither the
        // semantic resolver nor System Events UI scripting can find "Action".
        .accessibilityHidden(true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Defer until the window exists and has been laid out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.writeButtonFrame()
        }
    }

    /// Reports the approximate center of the window in CoreGraphics global
    /// coordinates (origin top-left, y growing downward) — the convention the
    /// coordinate layer / click_screen use.
    private func writeButtonFrame() {
        guard
            let window = NSApp.windows.first(where: { $0.isVisible }),
            let screen = window.screen ?? NSScreen.main
        else { return }

        let f = window.frame // AppKit: origin bottom-left, y growing upward.
        let screenHeight = screen.frame.height
        let centerXCocoa = f.midX
        let centerYCocoa = f.midY
        let cgX = centerXCocoa
        let cgY = screenHeight - centerYCocoa // flip to top-left origin.

        let payload: [String: Any] = [
            "x": cgX,
            "y": cgY,
            "window_frame": [
                "x": f.origin.x, "y": f.origin.y,
                "width": f.size.width, "height": f.size.height
            ]
        ]
        guard
            let path = ProcessInfo.processInfo.environment["AXDEGRADED_HARNESS_FRAME_FILE"],
            !path.isEmpty,
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
