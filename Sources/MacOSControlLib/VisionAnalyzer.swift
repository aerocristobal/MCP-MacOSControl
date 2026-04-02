import Foundation
import Vision
import CoreGraphics
import AppKit
import CryptoKit

@available(macOS 13.0, *)
public class VisionAnalyzer {

    // MARK: - Result Caching

    /// Thread-safe cache for analysis results
    private static let cache = AnalysisCache()

    /// Cache actor for thread-safe result storage
    private actor AnalysisCache {
        private var storage: [String: CachedResult] = [:]
        private let ttl: TimeInterval = 2.0 // 2 second cache

        struct CachedResult {
            let result: Any
            let timestamp: Date
        }

        func get(key: String) -> Any? {
            guard let cached = storage[key] else { return nil }

            // Check if expired
            if Date().timeIntervalSince(cached.timestamp) > ttl {
                storage.removeValue(forKey: key)
                return nil
            }

            return cached.result
        }

        func set(key: String, value: Any) {
            storage[key] = CachedResult(result: value, timestamp: Date())

            // Clean up old entries (simple cleanup strategy)
            if storage.count > 100 {
                let cutoff = Date().addingTimeInterval(-ttl)
                storage = storage.filter { $0.value.timestamp > cutoff }
            }
        }
    }

    // MARK: - Image Classification

    /// Classify objects in an image
    public static func classifyImage(imageData: Data, topK: Int = 5) async throws -> [[String: Any]] {
        guard let cgImage = createCGImage(from: imageData) else {
            throw NSError(domain: "VisionAnalyzer", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }

        return try await classifyImage(cgImage: cgImage, topK: topK)
    }

    /// Classify objects in a CGImage
    public static func classifyImage(cgImage: CGImage, topK: Int = 5) async throws -> [[String: Any]] {
        // Generate cache key from image hash
        let cacheKey = "classify_\(cgImage.width)x\(cgImage.height)_\(topK)"

        // Check cache
        if let cached = await cache.get(key: cacheKey) as? [[String: Any]] {
            return cached
        }

        let results = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[[String: Any]], Error>) in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let topResults = Array(observations.prefix(topK))
                let results = topResults.map { observation in
                    [
                        "identifier": observation.identifier,
                        "confidence": Double(observation.confidence),
                        "confidencePercentage": Int(observation.confidence * 100)
                    ]
                }

                continuation.resume(returning: results)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }

        // Cache the results
        await cache.set(key: cacheKey, value: results)
        return results
    }

    // MARK: - Object Detection

    /// Detect objects in an image
    public static func detectObjects(imageData: Data, minimumConfidence: Float = 0.5) async throws -> [[String: Any]] {
        guard let cgImage = createCGImage(from: imageData) else {
            throw NSError(domain: "VisionAnalyzer", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }

        return try await detectObjects(cgImage: cgImage, minimumConfidence: minimumConfidence)
    }

    /// Detect objects in a CGImage
    public static func detectObjects(cgImage: CGImage, minimumConfidence: Float = 0.5) async throws -> [[String: Any]] {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[[String: Any]], Error>) in
            let request = VNRecognizeAnimalsRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations
                    .filter { $0.confidence >= minimumConfidence }
                    .map { observation -> [String: Any] in
                        let boundingBox = observation.boundingBox

                        // Convert normalized coordinates to pixel coordinates
                        let x = Int(boundingBox.origin.x * imageSize.width)
                        let y = Int((1 - boundingBox.origin.y - boundingBox.height) * imageSize.height)
                        let width = Int(boundingBox.width * imageSize.width)
                        let height = Int(boundingBox.height * imageSize.height)

                        var labels: [[String: Any]] = []
                        if !observation.labels.isEmpty {
                            labels = observation.labels.prefix(3).map { label in
                                [
                                    "identifier": label.identifier,
                                    "confidence": Double(label.confidence),
                                    "confidencePercentage": Int(label.confidence * 100)
                                ]
                            }
                        }

                        return [
                            "boundingBox": [
                                "x": x,
                                "y": y,
                                "width": width,
                                "height": height
                            ],
                            "labels": labels,
                            "confidence": Double(observation.confidence),
                            "confidencePercentage": Int(observation.confidence * 100)
                        ]
                    }

                continuation.resume(returning: results)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Rectangle Detection

    /// Detect rectangles in an image (useful for UI elements, documents, etc.)
    public static func detectRectangles(imageData: Data, minimumConfidence: Float = 0.5) async throws -> [[String: Any]] {
        guard let cgImage = createCGImage(from: imageData) else {
            throw NSError(domain: "VisionAnalyzer", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }

        return try await detectRectangles(cgImage: cgImage, minimumConfidence: minimumConfidence)
    }

    /// Detect rectangles in a CGImage
    public static func detectRectangles(cgImage: CGImage, minimumConfidence: Float = 0.5) async throws -> [[String: Any]] {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[[String: Any]], Error>) in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations
                    .filter { $0.confidence >= minimumConfidence }
                    .map { observation -> [String: Any] in
                        let boundingBox = observation.boundingBox

                        // Convert normalized coordinates to pixel coordinates
                        let x = Int(boundingBox.origin.x * imageSize.width)
                        let y = Int((1 - boundingBox.origin.y - boundingBox.height) * imageSize.height)
                        let width = Int(boundingBox.width * imageSize.width)
                        let height = Int(boundingBox.height * imageSize.height)

                        // Get corner points
                        let topLeft = [
                            Int(observation.topLeft.x * imageSize.width),
                            Int((1 - observation.topLeft.y) * imageSize.height)
                        ]
                        let topRight = [
                            Int(observation.topRight.x * imageSize.width),
                            Int((1 - observation.topRight.y) * imageSize.height)
                        ]
                        let bottomRight = [
                            Int(observation.bottomRight.x * imageSize.width),
                            Int((1 - observation.bottomRight.y) * imageSize.height)
                        ]
                        let bottomLeft = [
                            Int(observation.bottomLeft.x * imageSize.width),
                            Int((1 - observation.bottomLeft.y) * imageSize.height)
                        ]

                        return [
                            "boundingBox": [
                                "x": x,
                                "y": y,
                                "width": width,
                                "height": height
                            ],
                            "corners": [
                                "topLeft": topLeft,
                                "topRight": topRight,
                                "bottomRight": bottomRight,
                                "bottomLeft": bottomLeft
                            ],
                            "confidence": Double(observation.confidence),
                            "confidencePercentage": Int(observation.confidence * 100)
                        ]
                    }

                continuation.resume(returning: results)
            }

            request.minimumConfidence = minimumConfidence
            request.maximumObservations = 20

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Saliency Detection

    /// Detect salient (attention-grabbing) regions in an image
    public static func detectSaliency(imageData: Data) async throws -> [String: Any] {
        guard let cgImage = createCGImage(from: imageData) else {
            throw NSError(domain: "VisionAnalyzer", code: 4,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }

        return try await detectSaliency(cgImage: cgImage)
    }

    /// Detect saliency in a CGImage
    public static func detectSaliency(cgImage: CGImage) async throws -> [String: Any] {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                    continuation.resume(returning: [:])
                    return
                }

                var salientObjects: [[String: Any]] = []
                if let objects = observation.salientObjects {
                    salientObjects = objects.map { object in
                        let boundingBox = object.boundingBox

                        let x = Int(boundingBox.origin.x * imageSize.width)
                        let y = Int((1 - boundingBox.origin.y - boundingBox.height) * imageSize.height)
                        let width = Int(boundingBox.width * imageSize.width)
                        let height = Int(boundingBox.height * imageSize.height)

                        return [
                            "boundingBox": [
                                "x": x,
                                "y": y,
                                "width": width,
                                "height": height
                            ],
                            "confidence": Double(object.confidence)
                        ]
                    }
                }

                let result: [String: Any] = [
                    "salientObjects": salientObjects,
                    "objectCount": salientObjects.count
                ]

                continuation.resume(returning: result)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Face Detection

    /// Detect faces in an image
    public static func detectFaces(imageData: Data) async throws -> [[String: Any]] {
        guard let cgImage = createCGImage(from: imageData) else {
            throw NSError(domain: "VisionAnalyzer", code: 5,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }

        return try await detectFaces(cgImage: cgImage)
    }

    /// Detect faces in a CGImage
    public static func detectFaces(cgImage: CGImage) async throws -> [[String: Any]] {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[[String: Any]], Error>) in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.map { observation -> [String: Any] in
                    let boundingBox = observation.boundingBox

                    let x = Int(boundingBox.origin.x * imageSize.width)
                    let y = Int((1 - boundingBox.origin.y - boundingBox.height) * imageSize.height)
                    let width = Int(boundingBox.width * imageSize.width)
                    let height = Int(boundingBox.height * imageSize.height)

                    return [
                        "boundingBox": [
                            "x": x,
                            "y": y,
                            "width": width,
                            "height": height
                        ],
                        "confidence": Double(observation.confidence),
                        "roll": observation.roll?.doubleValue ?? 0,
                        "yaw": observation.yaw?.doubleValue ?? 0
                    ]
                }

                continuation.resume(returning: results)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Helper Methods

    private static func createCGImage(from data: Data) -> CGImage? {
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
    }
}
