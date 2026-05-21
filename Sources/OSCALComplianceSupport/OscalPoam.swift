// STORY-037 — OSCAL Plan of Action and Milestones (POA&M) Codable view.
//
// Only the fields the emitter and drift checker actually read/write are
// modeled — the NIST OSCAL CLI is the authority for full schema
// validation. Round-trip preservation of unknown keys is intentionally
// NOT attempted here; this writer always re-emits the canonical shape
// we control, which is exactly what `oscal-cli validate` checks.
//
// Schema target: OSCAL POA&M 1.1.2.

import Foundation

public struct OscalPoamMilestone: Codable, Equatable {
    public let uuid: String
    public let title: String
    public let description: String
    public let targetDate: String?     // ISO 8601 yyyy-mm-dd or sprint label

    public init(uuid: String, title: String, description: String, targetDate: String? = nil) {
        self.uuid = uuid
        self.title = title
        self.description = description
        self.targetDate = targetDate
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case description
        case targetDate = "target-date"
    }
}

public struct OscalPoamRelatedControl: Codable, Equatable {
    public let controlId: String

    public init(controlId: String) {
        self.controlId = controlId
    }

    enum CodingKeys: String, CodingKey {
        case controlId = "control-id"
    }
}

public struct OscalPoamRelatedObservation: Codable, Equatable {
    public let observationUuid: String

    public init(observationUuid: String) {
        self.observationUuid = observationUuid
    }

    enum CodingKeys: String, CodingKey {
        case observationUuid = "observation-uuid"
    }
}

/// One row in the POA&M. `status` and structured risk metadata are
/// surfaced via `props` so downstream OSCAL consumers can read them
/// without inspecting `remarks` prose — but `remarks` keeps the human
/// narrative for assessors who do read it.
public struct OscalPoamItem: Codable, Equatable {
    public let uuid: String
    public let title: String
    public let description: String
    public let props: [OscalProp]?
    public let links: [OscalLink]?
    public let relatedControls: [OscalPoamRelatedControl]?
    public let relatedObservations: [OscalPoamRelatedObservation]?
    public let milestones: [OscalPoamMilestone]?
    public let remarks: String?

    public init(
        uuid: String,
        title: String,
        description: String,
        props: [OscalProp]? = nil,
        links: [OscalLink]? = nil,
        relatedControls: [OscalPoamRelatedControl]? = nil,
        relatedObservations: [OscalPoamRelatedObservation]? = nil,
        milestones: [OscalPoamMilestone]? = nil,
        remarks: String? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.description = description
        self.props = props
        self.links = links
        self.relatedControls = relatedControls
        self.relatedObservations = relatedObservations
        self.milestones = milestones
        self.remarks = remarks
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case description
        case props
        case links
        case relatedControls = "related-controls"
        case relatedObservations = "related-observations"
        case milestones
        case remarks
    }

    // MARK: - Property accessors

    /// Status surfaced as `props[name=status]`. The convention used by
    /// downstream OSCAL tooling: "risk-accepted", "open", "closed",
    /// "ongoing", "investigating".
    public var status: String? {
        props?.first(where: { $0.name == "status" })?.value
    }

    /// Owner surfaced as `props[name=poam-owner]`.
    public var owner: String? {
        props?.first(where: { $0.name == "poam-owner" })?.value
    }

    /// Reference back to the SECURITY.md subsection that authored this
    /// item — surfaced as `props[name=security-md-section]` with values
    /// like "4.1", "4.2". Used by drift detection.
    public var securityMdSection: String? {
        props?.first(where: { $0.name == "security-md-section" })?.value
    }
}

public struct OscalPoamSystemId: Codable, Equatable {
    public let id: String
    public let identifierType: String

    public init(id: String, identifierType: String) {
        self.id = id
        self.identifierType = identifierType
    }

    enum CodingKeys: String, CodingKey {
        case id
        case identifierType = "identifier-type"
    }
}

public struct OscalImportSsp: Codable, Equatable {
    public let href: String

    public init(href: String) {
        self.href = href
    }
}

public struct OscalPoamBody: Codable, Equatable {
    public var uuid: String
    public var metadata: OscalMetadata
    public var importSsp: OscalImportSsp?
    public var systemId: OscalPoamSystemId
    public var poamItems: [OscalPoamItem]
    public var observations: [OscalObservation]?

    public init(
        uuid: String,
        metadata: OscalMetadata,
        importSsp: OscalImportSsp?,
        systemId: OscalPoamSystemId,
        poamItems: [OscalPoamItem],
        observations: [OscalObservation]? = nil
    ) {
        self.uuid = uuid
        self.metadata = metadata
        self.importSsp = importSsp
        self.systemId = systemId
        self.poamItems = poamItems
        self.observations = observations
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case metadata
        case importSsp = "import-ssp"
        case systemId = "system-id"
        case poamItems = "poam-items"
        case observations
    }
}

public struct OscalPoamDocument: Codable, Equatable {
    public var planOfActionAndMilestones: OscalPoamBody

    public init(planOfActionAndMilestones: OscalPoamBody) {
        self.planOfActionAndMilestones = planOfActionAndMilestones
    }

    enum CodingKeys: String, CodingKey {
        case planOfActionAndMilestones = "plan-of-action-and-milestones"
    }

    // MARK: - Disk I/O

    public static func load(from url: URL) throws -> OscalPoamDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(OscalPoamDocument.self, from: data)
    }

    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}
