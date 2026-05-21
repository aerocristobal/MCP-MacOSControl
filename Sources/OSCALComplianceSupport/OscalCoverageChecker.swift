import Foundation

public enum OscalCoverageError: Error, CustomStringConvertible {
    case componentDefinitionUnreadable(path: String, underlying: Error)
    case componentDefinitionInvalidJson(path: String, underlying: Error)
    case securityMdUnreadable(path: String, underlying: Error)
    case statementMissing(controlId: String)

    public var description: String {
        switch self {
        case .componentDefinitionUnreadable(let path, let err):
            return "OSCAL component-definition at \(path) could not be read: \(err)"
        case .componentDefinitionInvalidJson(let path, let err):
            return "OSCAL component-definition at \(path) is not valid JSON: \(err)"
        case .securityMdUnreadable(let path, let err):
            return "SECURITY.md at \(path) could not be read: \(err)"
        case .statementMissing(let id):
            return "OSCAL component-definition has no implemented-requirement for control \(id)"
        }
    }
}

public struct OscalCoverageReport: Equatable {
    public let implementedControls: Set<String>
    public let securityMdControls: Set<String>
    public let missingControls: Set<String>     // claimed in SECURITY.md but absent from OSCAL
    public let extraControls: Set<String>       // present in OSCAL but not claimed in SECURITY.md
}

public struct OscalControlView: Equatable {
    public let controlId: String
    public let description: String
    public let implementingFiles: [String]
    public let verificationFiles: [String]
    public let hasAlternativeImplementations: Bool
    public let implementationStatus: String?    // "implemented" | "partial" | "alternative" | "not-applicable" | nil

    // Story §6 scaffold uses these property names; alias for compatibility.
    public var implementing_files: [String] { implementingFiles }
    public var test_files: [String] { verificationFiles }
}

public final class OscalCoverageChecker {

    private let componentDefinitionPath: String
    private let securityMdPath: String?
    private let securityMdOverride: String?
    private let extractor = SecurityMdControlExtractor()

    public init(componentDefinitionPath: String, securityMdPath: String) {
        self.componentDefinitionPath = componentDefinitionPath
        self.securityMdPath = securityMdPath
        self.securityMdOverride = nil
    }

    public init(componentDefinitionPath: String, securityMdContent: String) {
        self.componentDefinitionPath = componentDefinitionPath
        self.securityMdPath = nil
        self.securityMdOverride = securityMdContent
    }

    // MARK: - Parsing

    public func parsedComponentDefinition() throws -> OscalComponentDefinitionDocument {
        let url = URL(fileURLWithPath: componentDefinitionPath)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw OscalCoverageError.componentDefinitionUnreadable(path: componentDefinitionPath, underlying: error)
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(OscalComponentDefinitionDocument.self, from: data)
        } catch {
            throw OscalCoverageError.componentDefinitionInvalidJson(path: componentDefinitionPath, underlying: error)
        }
    }

    private func securityMdContent() throws -> String {
        if let override = securityMdOverride { return override }
        guard let path = securityMdPath else {
            return ""
        }
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw OscalCoverageError.securityMdUnreadable(path: path, underlying: error)
        }
    }

    // MARK: - Coverage report

    public func report() throws -> OscalCoverageReport {
        let doc = try parsedComponentDefinition()
        let oscalControls = Set(doc.implementedRequirements.map { $0.controlId.lowercased() })

        let md = try securityMdContent()
        let mentions = extractor.extract(from: md)
        let claimed = Set(mentions.map { $0.id })

        return OscalCoverageReport(
            implementedControls: oscalControls,
            securityMdControls: claimed,
            missingControls: claimed.subtracting(oscalControls),
            extraControls: oscalControls.subtracting(claimed)
        )
    }

    // MARK: - Per-control view

    public func statement(for controlId: String) throws -> OscalControlView {
        let needle = controlId.lowercased()
        let doc = try parsedComponentDefinition()
        guard let req = doc.implementedRequirements.first(where: { $0.controlId.lowercased() == needle }) else {
            throw OscalCoverageError.statementMissing(controlId: needle)
        }

        let allLinks = (req.links ?? []) + (req.statements?.flatMap { $0.links ?? [] } ?? [])
        let implementing = allLinks.filter { $0.rel == "implementation" }.map { $0.href }
        let verification = allLinks.filter { $0.rel == "verification" }.map { $0.href }

        let statusProp = req.props?.first { $0.name == "implementation-status" }?.value
        let hasAlternativeStatement = req.statements?.contains { stmt in
            (stmt.props?.contains { $0.name == "implementation-status" && ($0.value == "alternative" || $0.value == "planned") }) ?? false
        } ?? false

        return OscalControlView(
            controlId: needle,
            description: req.description,
            implementingFiles: implementing,
            verificationFiles: verification,
            hasAlternativeImplementations: hasAlternativeStatement || statusProp == "alternative",
            implementationStatus: statusProp
        )
    }
}
