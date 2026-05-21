import Foundation

// A minimal Codable view of NIST OSCAL Component Definition v1.1.2.
// Only fields the drift checker reads are modeled; unknown fields are
// preserved across decode but discarded — the OSCAL CLI is the authority
// for full schema validation.

public struct OscalLink: Codable, Equatable {
    public let href: String
    public let rel: String
    public let text: String?

    public init(href: String, rel: String, text: String? = nil) {
        self.href = href
        self.rel = rel
        self.text = text
    }
}

public struct OscalStatement: Codable, Equatable {
    public let statementId: String
    public let uuid: String
    public let description: String
    public let remarks: String?
    public let props: [OscalProp]?
    public let links: [OscalLink]?

    enum CodingKeys: String, CodingKey {
        case statementId = "statement-id"
        case uuid
        case description
        case remarks
        case props
        case links
    }
}

public struct OscalImplementedRequirement: Codable, Equatable {
    public let uuid: String
    public let controlId: String
    public let description: String
    public let props: [OscalProp]?
    public let links: [OscalLink]?
    public let statements: [OscalStatement]?

    enum CodingKeys: String, CodingKey {
        case uuid
        case controlId = "control-id"
        case description
        case props
        case links
        case statements
    }
}

public struct OscalProp: Codable, Equatable {
    public let name: String
    public let value: String
    public let ns: String?
    public let `class`: String?
    public let remarks: String?

    public init(name: String, value: String, ns: String? = nil, class: String? = nil, remarks: String? = nil) {
        self.name = name
        self.value = value
        self.ns = ns
        self.`class` = `class`
        self.remarks = remarks
    }
}

public struct OscalControlImplementation: Codable, Equatable {
    public let uuid: String
    public let source: String
    public let description: String
    public let implementedRequirements: [OscalImplementedRequirement]

    enum CodingKeys: String, CodingKey {
        case uuid
        case source
        case description
        case implementedRequirements = "implemented-requirements"
    }
}

public struct OscalComponent: Codable, Equatable {
    public let uuid: String
    public let type: String
    public let title: String
    public let description: String
    public let purpose: String?
    public let props: [OscalProp]?
    public let links: [OscalLink]?
    public let controlImplementations: [OscalControlImplementation]?

    enum CodingKeys: String, CodingKey {
        case uuid
        case type
        case title
        case description
        case purpose
        case props
        case links
        case controlImplementations = "control-implementations"
    }
}

public struct OscalParty: Codable, Equatable {
    public let uuid: String
    public let type: String
    public let name: String
}

public struct OscalMetadata: Codable, Equatable {
    public let title: String
    public let lastModified: String
    public let version: String
    public let oscalVersion: String
    public let parties: [OscalParty]?

    public init(title: String, lastModified: String, version: String, oscalVersion: String, parties: [OscalParty]? = nil) {
        self.title = title
        self.lastModified = lastModified
        self.version = version
        self.oscalVersion = oscalVersion
        self.parties = parties
    }

    enum CodingKeys: String, CodingKey {
        case title
        case lastModified = "last-modified"
        case version
        case oscalVersion = "oscal-version"
        case parties
    }
}

public struct OscalComponentDefinitionBody: Codable, Equatable {
    public let uuid: String
    public let metadata: OscalMetadata
    public let components: [OscalComponent]
}

public struct OscalComponentDefinitionDocument: Codable, Equatable {
    public let componentDefinition: OscalComponentDefinitionBody

    enum CodingKeys: String, CodingKey {
        case componentDefinition = "component-definition"
    }
}

// MARK: - Convenience accessors used by the drift checker

extension OscalComponentDefinitionDocument {
    public var primaryComponent: OscalComponent {
        guard let first = componentDefinition.components.first else {
            fatalError("OSCAL component-definition contains no components — schema invariant violated")
        }
        return first
    }

    public var implementedRequirements: [OscalImplementedRequirement] {
        primaryComponent.controlImplementations?.flatMap { $0.implementedRequirements } ?? []
    }

    public var links: [OscalLink] {
        primaryComponent.links ?? []
    }
}
