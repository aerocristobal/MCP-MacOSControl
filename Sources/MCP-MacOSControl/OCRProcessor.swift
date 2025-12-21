import Foundation
import Vision
import CoreGraphics
import AppKit

class OCRProcessor {

    /// Perform OCR on a screenshot and return text with coordinates
    static func performOCR(on imageData: Data) async throws -> [[Any]] {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "OCRProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage from data"])
        }

        return try await performOCROnCGImage(cgImage: cgImage, imageSize: image.size)
    }

    /// Perform OCR on a CGImage
    private static func performOCROnCGImage(cgImage: CGImage, imageSize: NSSize) async throws -> [[Any]] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var results: [[Any]] = []

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else {
                        continue
                    }

                    let text = topCandidate.string
                    let confidence = topCandidate.confidence

                    // Convert normalized coordinates to pixel coordinates
                    let boundingBox = observation.boundingBox

                    // Vision framework uses bottom-left origin, convert to top-left
                    let x = boundingBox.origin.x * imageSize.width
                    let y = (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height
                    let width = boundingBox.width * imageSize.width
                    let height = boundingBox.height * imageSize.height

                    // Create bounding box as array of corner points [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
                    let topLeft = [Int(x), Int(y)]
                    let topRight = [Int(x + width), Int(y)]
                    let bottomRight = [Int(x + width), Int(y + height)]
                    let bottomLeft = [Int(x), Int(y + height)]

                    let coordinates = [topLeft, topRight, bottomRight, bottomLeft]

                    // Return format: [coordinates, text, confidence]
                    results.append([coordinates, text, Double(confidence)])
                }

                continuation.resume(returning: results)
            }

            // Configure request for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Take screenshot with OCR
    static func takeScreenshotWithOCR(
        titlePattern: String? = nil,
        useRegex: Bool = false,
        threshold: Int = 60,
        saveToDownloads: Bool = false
    ) async throws -> (ocrResults: [[Any]], metadata: [String: Any]) {

        // Take screenshot
        let screenshot = try await ScreenCapture.takeScreenshot(
            titlePattern: titlePattern,
            useRegex: useRegex,
            threshold: threshold,
            saveToDownloads: saveToDownloads
        )

        // Perform OCR
        let ocrResults = try await performOCR(on: screenshot.imageData)

        return (ocrResults: ocrResults, metadata: screenshot.metadata)
    }
}
