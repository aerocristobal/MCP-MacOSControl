// STORY-037 — OSCAL Plan of Action and Milestones (POA&M) Codable view.
//
// Strict OSCAL POA&M 1.1.2 places the substantive content on `risk`
// entries — status, links to controls, risk-log, remediations (tasks /
// milestones), related-observations — while `poam-items` are short
// tracking handles that reference risks via `related-risks`. We model
// only the fields we read or write; OSCAL CLI is the schema authority.

import Foundation

// MARK: - Task / Timing

public struct OscalTimingOnDate: Codable, Equatable {
    public let date: String

    public init(date: String) {
        self.date = date
    }
}

public struct OscalTaskTiming: Codable, Equatable {
    public let onDate: OscalTimingOnDate?

    public init(onDate: OscalTimingOnDate? = nil) {
        self.onDate = onDate
    }

    enum CodingKeys: String, CodingKey {
        case onDate = "on-date"
    }
}

public struct OscalTask: Codable, Equatable {
    public let uuid: String
    public let type: String        // "milestone" | "action"
    public let title: String
    public let description: String?
    public let timing: OscalTaskTiming?

    public init(uuid: String, type: String, title: String, description: String? = nil, timing: OscalTaskTiming? = nil) {
        self.uuid = uuid
        self.type = type
        self.title = title
        self.description = description
        self.timing = timing
    }

    /// Target date string (yyyy-mm-dd or ISO-8601) when one is declared
    /// via `timing.on-date.date`. Used by tests.
    public var targetDate: String? { timing?.onDate?.date }
}

// MARK: - Remediation (response)

public struct OscalRemediation: Codable, Equatable {
    public let uuid: String
    public let lifecycle: String    // "recommendation" | "planned" | "completed"
    public let title: String
    public let description: String?
    public let tasks: [OscalTask]?

    public init(uuid: String, lifecycle: String, title: String, description: String? = nil, tasks: [OscalTask]? = nil) {
        self.uuid = uuid
        self.lifecycle = lifecycle
        self.title = title
        self.description = description
        self.tasks = tasks
    }

    public var milestones: [OscalTask] {
        (tasks ?? []).filter { $0.type == "milestone" }
    }
}

// MARK: - Risk log

public struct OscalRiskLogEntry: Codable, Equatable {
    public let uuid: String
    public let title: String?
    public let description: String?
    public let start: String
    public let statusChange: String?

    public init(uuid: String, title: String? = nil, description: String? = nil, start: String, statusChange: String? = nil) {
        self.uuid = uuid
        self.title = title
        self.description = description
        self.start = start
        self.statusChange = statusChange
    }

    enum CodingKeys: String, CodingKey {
        case uuid, title, description, start
        case statusChange = "status-change"
    }
}

public struct OscalRiskLog: Codable, Equatable {
    public let entries: [OscalRiskLogEntry]

    public init(entries: [OscalRiskLogEntry]) {
        self.entries = entries
    }
}

// MARK: - Risk

public struct OscalRiskRelatedObservation: Codable, Equatable {
    public let observationUuid: String

    public init(observationUuid: String) {
        self.observationUuid = observationUuid
    }

    enum CodingKeys: String, CodingKey {
        case observationUuid = "observation-uuid"
    }
}

public struct OscalRisk: Codable, Equatable {
    public let uuid: String
    public let title: String
    public let description: String
    public let statement: String
    public let status: String       // open | investigating | remediating | deviation-requested | deviation-approved | closed
    public let props: [OscalProp]?
    public let links: [OscalLink]?
    public let riskLog: OscalRiskLog?
    public let remediations: [OscalRemediation]?
    public let relatedObservations: [OscalRiskRelatedObservation]?

    public init(
        uuid: String,
        title: String,
        description: String,
        statement: String,
        status: String,
        props: [OscalProp]? = nil,
        links: [OscalLink]? = nil,
        riskLog: OscalRiskLog? = nil,
        remediations: [OscalRemediation]? = nil,
        relatedObservations: [OscalRiskRelatedObservation]? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.description = description
        self.statement = statement
        self.status = status
        self.props = props
        self.links = links
        self.riskLog = riskLog
        self.remediations = remediations
        self.relatedObservations = relatedObservations
    }

    enum CodingKeys: String, CodingKey {
        case uuid, title, description, statement, status, props, links
        case riskLog = "risk-log"
        case remediations
        case relatedObservations = "related-observations"
    }

    // MARK: - Convenience prop accessors

    /// Status surfaced as `props[name=poam-owner]`.
    public var owner: String? {
        props?.first(where: { $0.name == "poam-owner" })?.value
    }

    /// Reference back to the SECURITY.md subsection that authored this
    /// risk — surfaced as `props[name=security-md-section]` with values
    /// like "4.1", "4.2". Used by drift detection.
    public var securityMdSection: String? {
        props?.first(where: { $0.name == "security-md-section" })?.value
    }

    /// All milestone tasks across all remediations. Convenience for
    /// reporting and tests.
    public var milestones: [OscalTask] {
        (remediations ?? []).flatMap { $0.milestones }
    }
}

// MARK: - POA&M item

public struct OscalPoamRelatedRisk: Codable, Equatable {
    public let riskUuid: String

    public init(riskUuid: String) {
        self.riskUuid = riskUuid
    }

    enum CodingKeys: String, CodingKey {
        case riskUuid = "risk-uuid"
    }
}

/// A POA&M item is a short action-tracking handle. The substantive
/// state (status, owner, milestones) lives on the linked risk.
public struct OscalPoamItem: Codable, Equatable {
    public let uuid: String?       // optional per OSCAL POA&M schema
    public let title: String
    public let description: String
    public let props: [OscalProp]?
    public let links: [OscalLink]?
    public let relatedRisks: [OscalPoamRelatedRisk]?
    public let remarks: String?

    public init(
        uuid: String? = nil,
        title: String,
        description: String,
        props: [OscalProp]? = nil,
        links: [OscalLink]? = nil,
        relatedRisks: [OscalPoamRelatedRisk]? = nil,
        remarks: String? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.description = description
        self.props = props
        self.links = links
        self.relatedRisks = relatedRisks
        self.remarks = remarks
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case description
        case props
        case links
        case relatedRisks = "related-risks"
        case remarks
    }
}

// MARK: - System identification

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

// MARK: - Document body

public struct OscalPoamBody: Codable, Equatable {
    public var uuid: String
    public var metadata: OscalMetadata
    public var importSsp: OscalImportSsp?
    public var systemId: OscalPoamSystemId
    public var risks: [OscalRisk]?
    public var poamItems: [OscalPoamItem]
    public var observations: [OscalObservation]?

    public init(
        uuid: String,
        metadata: OscalMetadata,
        importSsp: OscalImportSsp?,
        systemId: OscalPoamSystemId,
        risks: [OscalRisk]? = nil,
        poamItems: [OscalPoamItem],
        observations: [OscalObservation]? = nil
    ) {
        self.uuid = uuid
        self.metadata = metadata
        self.importSsp = importSsp
        self.systemId = systemId
        self.risks = risks
        self.poamItems = poamItems
        self.observations = observations
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case metadata
        case importSsp = "import-ssp"
        case systemId = "system-id"
        case risks
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

    // MARK: - Convenience accessors

    public var risks: [OscalRisk] {
        planOfActionAndMilestones.risks ?? []
    }

    public var poamItems: [OscalPoamItem] {
        planOfActionAndMilestones.poamItems
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
