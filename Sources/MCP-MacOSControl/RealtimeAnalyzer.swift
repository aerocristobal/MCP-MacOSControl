import Foundation
import CoreGraphics
import AppKit

@available(macOS 13.0, *)
class RealtimeAnalyzer {

    private var captureManager: ContinuousCaptureManager?
    private var analysisResults: [String: Any] = [:]
    private var isAnalyzing = false

    // MARK: - Combined Capture + Analysis

    /// Capture and analyze in real-time
    func startRealtimeAnalysis(
        captureType: ContinuousCaptureManager.CaptureType,
        targetIdentifier: String?,
        frameRate: Int = 10,
        analysisTypes: [AnalysisType]
    ) async throws {
        captureManager = ContinuousCaptureManager()
        isAnalyzing = true

        try await captureManager?.startCapture(
            type: captureType,
            targetIdentifier: targetIdentifier,
            frameRate: frameRate
        ) { [weak self] frame in
            guard let self = self, self.isAnalyzing else { return }

            Task {
                await self.analyzeFrame(frame, types: analysisTypes)
            }
        }
    }

    /// Stop real-time analysis
    func stopRealtimeAnalysis() async throws {
        isAnalyzing = false
        if let manager = captureManager {
            try await manager.stopCapture()
        }
        captureManager = nil
    }

    /// Get latest analysis results
    func getLatestAnalysis() -> [String: Any] {
        return analysisResults
    }

    /// Quick capture and analyze current screen
    static func quickAnalyze(
        captureType: ContinuousCaptureManager.CaptureType = .display,
        targetIdentifier: String? = nil,
        analysisTypes: [AnalysisType]
    ) async throws -> [String: Any] {
        // Start capture
        let manager = ContinuousCaptureManager()
        var capturedFrame: CGImage?

        try await manager.startCapture(
            type: captureType,
            targetIdentifier: targetIdentifier,
            frameRate: 1
        ) { frame in
            capturedFrame = frame
        }

        // Wait for a frame
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Stop capture
        try await manager.stopCapture()

        guard let frame = capturedFrame else {
            throw NSError(domain: "RealtimeAnalyzer", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "No frame captured"])
        }

        // Analyze the frame
        var results: [String: Any] = [:]

        for analysisType in analysisTypes {
            switch analysisType {
            case .classification(let topK):
                let classifications = try await VisionAnalyzer.classifyImage(cgImage: frame, topK: topK)
                results["classifications"] = classifications

            case .objectDetection(let minConfidence):
                let objects = try await VisionAnalyzer.detectObjects(cgImage: frame, minimumConfidence: minConfidence)
                results["objects"] = objects

            case .rectangles(let minConfidence):
                let rectangles = try await VisionAnalyzer.detectRectangles(cgImage: frame, minimumConfidence: minConfidence)
                results["rectangles"] = rectangles

            case .saliency:
                let saliency = try await VisionAnalyzer.detectSaliency(cgImage: frame)
                results["saliency"] = saliency

            case .faces:
                let faces = try await VisionAnalyzer.detectFaces(cgImage: frame)
                results["faces"] = faces

            case .ocr:
                // Convert CGImage to Data for OCR
                let nsImage = NSImage(cgImage: frame, size: NSSize(width: frame.width, height: frame.height))
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    let ocrResults = try await OCRProcessor.performOCR(on: pngData)
                    results["text"] = ocrResults
                }
            }
        }

        results["timestamp"] = Date().timeIntervalSince1970
        results["frameSize"] = ["width": frame.width, "height": frame.height]

        return results
    }

    // MARK: - Private Methods

    private func analyzeFrame(_ frame: CGImage, types: [AnalysisType]) async {
        var results: [String: Any] = [:]

        for analysisType in types {
            do {
                switch analysisType {
                case .classification(let topK):
                    let classifications = try await VisionAnalyzer.classifyImage(cgImage: frame, topK: topK)
                    results["classifications"] = classifications

                case .objectDetection(let minConfidence):
                    let objects = try await VisionAnalyzer.detectObjects(cgImage: frame, minimumConfidence: minConfidence)
                    results["objects"] = objects

                case .rectangles(let minConfidence):
                    let rectangles = try await VisionAnalyzer.detectRectangles(cgImage: frame, minimumConfidence: minConfidence)
                    results["rectangles"] = rectangles

                case .saliency:
                    let saliency = try await VisionAnalyzer.detectSaliency(cgImage: frame)
                    results["saliency"] = saliency

                case .faces:
                    let faces = try await VisionAnalyzer.detectFaces(cgImage: frame)
                    results["faces"] = faces

                case .ocr:
                    // Convert CGImage to Data for OCR
                    let nsImage = NSImage(cgImage: frame, size: NSSize(width: frame.width, height: frame.height))
                    if let tiffData = nsImage.tiffRepresentation,
                       let bitmapImage = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                        let ocrResults = try await OCRProcessor.performOCR(on: pngData)
                        results["text"] = ocrResults
                    }
                }
            } catch {
                results["error_\(analysisType.name)"] = error.localizedDescription
            }
        }

        results["timestamp"] = Date().timeIntervalSince1970
        results["frameSize"] = ["width": frame.width, "height": frame.height]

        self.analysisResults = results
    }

    // MARK: - Analysis Types

    enum AnalysisType {
        case classification(topK: Int)
        case objectDetection(minConfidence: Float)
        case rectangles(minConfidence: Float)
        case saliency
        case faces
        case ocr

        var name: String {
            switch self {
            case .classification: return "classification"
            case .objectDetection: return "objectDetection"
            case .rectangles: return "rectangles"
            case .saliency: return "saliency"
            case .faces: return "faces"
            case .ocr: return "ocr"
            }
        }
    }
}
