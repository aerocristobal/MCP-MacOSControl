import Foundation
import ScreenCaptureKit
import AppKit
import CoreMedia
import CoreImage

@available(macOS 13.0, *)
public class ContinuousCaptureManager: NSObject {

    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var isCapturing = false
    private var lastFrame: CGImage?
    private var frameCallback: ((CGImage) -> Void)?

    // Configuration
    private var captureType: CaptureType = .display
    private var targetIdentifier: String?
    private var frameRate: Int = 30

    // Singleton CIContext for efficient frame processing
    private static let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])

    public override init() {
        super.init()
    }

    public enum CaptureType {
        case display
        case window
        case application
    }

    // MARK: - Public API

    /// Start continuous capture
    public func startCapture(
        type: CaptureType,
        targetIdentifier: String? = nil,
        frameRate: Int = 30,
        onFrame: @escaping (CGImage) -> Void
    ) async throws {
        guard !isCapturing else {
            throw NSError(domain: "ContinuousCaptureManager", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Capture already in progress"])
        }

        self.captureType = type
        self.targetIdentifier = targetIdentifier
        self.frameRate = frameRate
        self.frameCallback = onFrame

        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Create configuration based on type
        let filter: SCContentFilter
        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        streamConfig.queueDepth = 3

        switch type {
        case .display:
            guard let display = try selectDisplay(from: content, identifier: targetIdentifier) else {
                throw NSError(domain: "ContinuousCaptureManager", code: 2,
                             userInfo: [NSLocalizedDescriptionKey: "Display not found"])
            }
            filter = SCContentFilter(display: display, excludingWindows: [])
            streamConfig.width = display.width
            streamConfig.height = display.height

        case .window:
            guard let window = try selectWindow(from: content, identifier: targetIdentifier) else {
                throw NSError(domain: "ContinuousCaptureManager", code: 3,
                             userInfo: [NSLocalizedDescriptionKey: "Window not found"])
            }
            filter = SCContentFilter(desktopIndependentWindow: window)
            streamConfig.width = Int(window.frame.width)
            streamConfig.height = Int(window.frame.height)

        case .application:
            guard let app = try selectApplication(from: content, identifier: targetIdentifier) else {
                throw NSError(domain: "ContinuousCaptureManager", code: 4,
                             userInfo: [NSLocalizedDescriptionKey: "Application not found"])
            }
            guard let display = content.displays.first else {
                throw NSError(domain: "ContinuousCaptureManager", code: 5,
                             userInfo: [NSLocalizedDescriptionKey: "No display available"])
            }
            filter = SCContentFilter(display: display, including: [app], exceptingWindows: [])
        }

        // Create stream output
        streamOutput = StreamOutput(onFrame: onFrame, manager: self)

        // Create and start stream
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: .main)
        try await stream?.startCapture()

        isCapturing = true
    }

    /// Stop continuous capture
    public func stopCapture() async throws {
        guard isCapturing else { return }

        if let stream = stream {
            try await stream.stopCapture()
        }

        stream = nil
        streamOutput = nil
        isCapturing = false
        lastFrame = nil
        frameCallback = nil
    }

    /// Get the latest captured frame
    public func getLatestFrame() -> CGImage? {
        return lastFrame
    }

    /// Check if currently capturing
    public func isCaptureActive() -> Bool {
        return isCapturing
    }

    // MARK: - Private Helpers

    private func selectDisplay(from content: SCShareableContent, identifier: String?) throws -> SCDisplay? {
        if let identifier = identifier {
            // Try to match by display ID
            if let displayID = UInt32(identifier) {
                return content.displays.first { $0.displayID == displayID }
            }
        }
        // Return main display
        return content.displays.first
    }

    private func selectWindow(from content: SCShareableContent, identifier: String?) throws -> SCWindow? {
        if let identifier = identifier {
            // Try to match by window ID
            if let windowID = UInt32(identifier) {
                return content.windows.first { $0.windowID == windowID }
            }
            // Try to match by title
            return content.windows.first { window in
                if let title = window.title, !title.isEmpty {
                    return title.lowercased().contains(identifier.lowercased())
                }
                return false
            }
        }
        return nil
    }

    private func selectApplication(from content: SCShareableContent, identifier: String?) throws -> SCRunningApplication? {
        if let identifier = identifier {
            // Try to match by bundle identifier
            if let app = content.applications.first(where: { $0.bundleIdentifier == identifier }) {
                return app
            }
            // Try to match by application name
            return content.applications.first { app in
                app.applicationName.lowercased().contains(identifier.lowercased())
            }
        }
        return nil
    }

    // MARK: - Stream Output Handler

    private class StreamOutput: NSObject, SCStreamOutput {
        private let onFrame: (CGImage) -> Void
        weak var manager: ContinuousCaptureManager?

        init(onFrame: @escaping (CGImage) -> Void, manager: ContinuousCaptureManager) {
            self.onFrame = onFrame
            self.manager = manager
        }

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            guard type == .screen,
                  let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }

            let ciImage = CIImage(cvImageBuffer: imageBuffer)

            // Use shared CIContext to avoid recreation overhead
            guard let cgImage = ContinuousCaptureManager.sharedCIContext.createCGImage(ciImage, from: ciImage.extent) else {
                return
            }

            // Store the latest frame
            manager?.lastFrame = cgImage

            // Call the frame callback
            onFrame(cgImage)
        }
    }
}

@available(macOS 13.0, *)
extension ContinuousCaptureManager {

    /// Get list of available displays
    public static func getAvailableDisplays() async throws -> [[String: Any]] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        return content.displays.map { display in
            [
                "displayID": display.displayID,
                "width": display.width,
                "height": display.height,
                "frame": [
                    "x": display.frame.origin.x,
                    "y": display.frame.origin.y,
                    "width": display.frame.width,
                    "height": display.frame.height
                ]
            ]
        }
    }

    /// Get list of available windows for capture
    public static func getCapturableWindows() async throws -> [[String: Any]] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        return content.windows.compactMap { window in
            guard let title = window.title, !title.isEmpty else { return nil }

            return [
                "windowID": window.windowID,
                "title": title,
                "ownerName": window.owningApplication?.applicationName ?? "",
                "bundleIdentifier": window.owningApplication?.bundleIdentifier ?? "",
                "frame": [
                    "x": window.frame.origin.x,
                    "y": window.frame.origin.y,
                    "width": window.frame.width,
                    "height": window.frame.height
                ]
            ]
        }
    }

    /// Get list of available applications for capture
    public static func getCapturableApplications() async throws -> [[String: Any]] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        return content.applications.map { app in
            [
                "bundleIdentifier": app.bundleIdentifier,
                "applicationName": app.applicationName,
                "processID": app.processID
            ]
        }
    }
}
