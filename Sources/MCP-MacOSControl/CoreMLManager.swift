import Foundation
import CoreML
import NaturalLanguage

@available(macOS 13.0, *)
class CoreMLManager {

    // MARK: - Model Management

    private static var loadedModels: [String: MLModel] = [:]
    private static var modelMetadata: [String: [String: Any]] = [:]

    /// List available CoreML models in a directory
    static func listAvailableModels(directory: String? = nil) throws -> [[String: Any]] {
        let searchPath: String
        if let dir = directory {
            searchPath = dir
        } else {
            // Default to user's Documents/MLModels directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            searchPath = documentsPath?.appendingPathComponent("MLModels").path ?? ""
        }

        guard FileManager.default.fileExists(atPath: searchPath) else {
            return []
        }

        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: searchPath)

        var models: [[String: Any]] = []
        for item in contents {
            if item.hasSuffix(".mlmodelc") || item.hasSuffix(".mlpackage") {
                let fullPath = (searchPath as NSString).appendingPathComponent(item)
                let modelName = (item as NSString).deletingPathExtension

                models.append([
                    "name": modelName,
                    "path": fullPath,
                    "type": item.hasSuffix(".mlmodelc") ? "compiled" : "package",
                    "loaded": loadedModels[modelName] != nil
                ])
            }
        }

        return models
    }

    /// Load a CoreML model from file path
    static func loadModel(name: String, path: String) throws -> String {
        let url = URL(fileURLWithPath: path)

        // Compile if needed
        let compiledURL: URL
        if path.hasSuffix(".mlpackage") {
            compiledURL = try MLModel.compileModel(at: url)
        } else {
            compiledURL = url
        }

        // Load the model
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all // Use CPU, GPU, and Neural Engine

        let model = try MLModel(contentsOf: compiledURL, configuration: configuration)

        // Store the model
        loadedModels[name] = model

        // Extract metadata
        let description = model.modelDescription
        var metadata: [String: Any] = [
            "inputDescriptions": description.inputDescriptionsByName.mapValues { desc in
                ["type": String(describing: desc.type), "name": desc.name]
            },
            "outputDescriptions": description.outputDescriptionsByName.mapValues { desc in
                ["type": String(describing: desc.type), "name": desc.name]
            }
        ]

        if let modelMetadata = description.metadata[.description] as? String {
            metadata["description"] = modelMetadata
        }
        if let author = description.metadata[.author] as? String {
            metadata["author"] = author
        }
        if let version = description.metadata[.versionString] as? String {
            metadata["version"] = version
        }

        modelMetadata[name] = metadata

        return "Model '\(name)' loaded successfully"
    }

    /// Unload a model from memory
    static func unloadModel(name: String) throws {
        guard loadedModels[name] != nil else {
            throw NSError(domain: "CoreMLManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model '\(name)' not loaded"])
        }

        loadedModels.removeValue(forKey: name)
        modelMetadata.removeValue(forKey: name)
    }

    /// Get model metadata
    static func getModelMetadata(name: String) throws -> [String: Any] {
        guard let metadata = modelMetadata[name] else {
            throw NSError(domain: "CoreMLManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Model '\(name)' not loaded"])
        }
        return metadata
    }

    // MARK: - Text Generation (for LLM models)

    /// Generate text using a loaded CoreML LLM model
    static func generateText(
        modelName: String,
        prompt: String,
        maxTokens: Int = 256,
        temperature: Double = 0.7,
        topK: Int = 50
    ) async throws -> String {
        guard let model = loadedModels[modelName] else {
            throw NSError(domain: "CoreMLManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Model '\(modelName)' not loaded. Use load_coreml_model first."])
        }

        // This is a generic interface - actual implementation depends on the model's input/output format
        // Most CoreML LLMs expect input as MLMultiArray or String and output tokens/probabilities

        let inputFeatures = try prepareLLMInput(prompt: prompt, model: model)
        let prediction = try model.prediction(from: inputFeatures)

        return try extractTextFromPrediction(prediction: prediction, maxTokens: maxTokens)
    }

    /// Generate text and analyze screen content together
    static func analyzeWithLLM(
        modelName: String,
        screenContent: [String: Any],
        instruction: String,
        maxTokens: Int = 512
    ) async throws -> [String: Any] {
        // Combine screen analysis results with LLM prompt
        var context = "Screen Analysis:\n"

        if let classification = screenContent["classification"] as? [[String: Any]] {
            context += "Scene: \(classification.first?["identifier"] ?? "unknown")\n"
        }

        if let ocrText = screenContent["ocr_text"] as? [[Any]] {
            context += "Text on screen:\n"
            for item in ocrText.prefix(20) {
                if item.count > 1 {
                    context += "- \(item[1])\n"
                }
            }
        }

        if let objects = screenContent["objects"] as? [[String: Any]] {
            context += "Detected objects: \(objects.count)\n"
        }

        let fullPrompt = "\(context)\nInstruction: \(instruction)\nResponse:"

        let response = try await generateText(
            modelName: modelName,
            prompt: fullPrompt,
            maxTokens: maxTokens
        )

        return [
            "prompt": fullPrompt,
            "response": response,
            "screen_content_summary": context
        ]
    }

    // MARK: - Helper Methods

    private static func prepareLLMInput(prompt: String, model: MLModel) throws -> MLFeatureProvider {
        let description = model.modelDescription

        // Find the text input feature
        guard let inputName = description.inputDescriptionsByName.keys.first(where: { key in
            let desc = description.inputDescriptionsByName[key]
            return desc?.type == .string || desc?.type == .multiArray
        }) else {
            throw NSError(domain: "CoreMLManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not find text input in model"])
        }

        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            inputName: prompt as NSString
        ])

        return inputFeatures
    }

    private static func extractTextFromPrediction(prediction: MLFeatureProvider, maxTokens: Int) throws -> String {
        // Try to find text output
        if let outputName = prediction.featureNames.first,
           let value = prediction.featureValue(for: outputName) {

            // Try string output
            let stringValue = value.stringValue
            if !stringValue.isEmpty {
                return stringValue
            }

            // Try multiarray output
            if let multiArrayValue = value.multiArrayValue {
                // Handle token IDs - would need tokenizer for proper decoding
                // This is a simplified version
                return "Generated \(multiArrayValue.count) tokens (tokenizer needed for decoding)"
            }

            // Try dictionary output
            let dictValue = value.dictionaryValue
            if !dictValue.isEmpty, let text = dictValue.keys.first as? String {
                return text
            }
        }

        throw NSError(domain: "CoreMLManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not extract text from model output"])
    }

    // MARK: - Natural Language Processing (using built-in NaturalLanguage framework)

    /// Summarize text using NaturalLanguage framework
    static func summarizeText(text: String, maxLength: Int = 200) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var sentences: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .lexicalClass) { tag, range in
            let sentence = String(text[range])
            sentences.append(sentence)
            return true
        }

        // Simple summarization: take first few sentences up to maxLength
        var summary = ""
        for sentence in sentences {
            if summary.count + sentence.count <= maxLength {
                summary += sentence
            } else {
                break
            }
        }

        return summary.isEmpty ? String(text.prefix(maxLength)) : summary
    }

    /// Extract key information from OCR results using NL
    static func extractKeyInfo(ocrResults: [[Any]]) -> [String: Any] {
        var allText = ""
        for result in ocrResults {
            if result.count > 1, let text = result[1] as? String {
                allText += text + " "
            }
        }

        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = allText

        var entities: [String: [String]] = [
            "people": [],
            "places": [],
            "organizations": []
        ]

        tagger.enumerateTags(in: allText.startIndex..<allText.endIndex, unit: .word, scheme: .nameType) { tag, range in
            guard let tag = tag else { return true }
            let word = String(allText[range])

            switch tag {
            case .personalName:
                entities["people"]?.append(word)
            case .placeName:
                entities["places"]?.append(word)
            case .organizationName:
                entities["organizations"]?.append(word)
            default:
                break
            }
            return true
        }

        return [
            "text_length": allText.count,
            "word_count": allText.split(separator: " ").count,
            "entities": entities,
            "summary": summarizeText(text: allText)
        ]
    }

    /// Intelligent screen content analysis combining Vision + NL
    static func intelligentScreenAnalysis(
        classificationResults: [[String: Any]]?,
        ocrResults: [[Any]]?,
        objectResults: [[String: Any]]?
    ) -> [String: Any] {
        var analysis: [String: Any] = [:]

        // Scene understanding
        if let classification = classificationResults?.first {
            analysis["primary_scene"] = classification["identifier"]
            analysis["scene_confidence"] = classification["confidence"]
        }

        // Text analysis
        if let ocr = ocrResults, !ocr.isEmpty {
            let textInfo = extractKeyInfo(ocrResults: ocr)
            analysis["text_analysis"] = textInfo
        }

        // Object summary
        if let objects = objectResults {
            let objectCounts = objects.reduce(into: [String: Int]()) { counts, obj in
                if let label = obj["label"] as? String {
                    counts[label, default: 0] += 1
                }
            }
            analysis["object_summary"] = objectCounts
            analysis["total_objects"] = objects.count
        }

        // Generate natural language summary
        var summary = ""
        if let scene = analysis["primary_scene"] as? String {
            summary += "This appears to be \(scene). "
        }
        if let textAnalysis = analysis["text_analysis"] as? [String: Any],
           let wordCount = textAnalysis["word_count"] as? Int {
            summary += "Contains \(wordCount) words of text. "
        }
        if let objectCount = analysis["total_objects"] as? Int, objectCount > 0 {
            summary += "Detected \(objectCount) objects on screen."
        }

        analysis["natural_summary"] = summary

        return analysis
    }
}
