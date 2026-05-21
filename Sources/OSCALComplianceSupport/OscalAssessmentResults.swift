// STORY-037 — OSCAL Assessment Results (AR) Codable view.
//
// Same scope policy as OscalPoam.swift: model only what we emit and what
// downstream code reads. `oscal-cli validate` is the schema authority.
//
// Append semantics:
//   * `load(from:)` parses an existing AR.
//   * `loadOrCreate(at:metadataTitle:)` returns the existing doc or builds
//     an empty one with sensible metadata defaults — used by the CLI on
//     a first-run.
//   * `appending(observations:)` returns a new document with the new
//     observations spliced into the first `result`'s `observations`
//     array. Existing observation UUIDs/content are unchanged; only
//     `metadata.last-modified` is updated. The "first result" choice is
//     deliberate: we maintain a single rolling-window result so the AR
//     stays grep-friendly. Splitting into multiple results-per-day would
//     fragment the evidence trail.
//
// Schema target: OSCAL Assessment Results 1.1.2.

import Foundation

public struct OscalObservationSubject: Codable, Equatable {
    public let subjectUuid: String
    public let type: String
    public let title: String?

    public init(subjectUuid: String, type: String, title: String? = nil) {
        self.subjectUuid = subjectUuid
        self.type = type
        self.title = title
    }

    enum CodingKeys: String, CodingKey {
        case subjectUuid = "subject-uuid"
        case type
        case title
    }
}

public struct OscalObservationRelevantEvidence: Codable, Equatable {
    public let href: String
    public let description: String?

    public init(href: String, description: String? = nil) {
        self.href = href
        self.description = description
    }
}

public struct OscalObservation: Codable, Equatable {
    public let uuid: String
    public let title: String
    public let description: String
    public let methods: [String]
    public let types: [String]?
    public let subjects: [OscalObservationSubject]?
    public let relevantEvidence: [OscalObservationRelevantEvidence]?
    public let collected: String
    public let props: [OscalProp]?
    public let links: [OscalLink]?
    public let remarks: String?

    public init(
        uuid: String,
        title: String,
        description: String,
        methods: [String],
        types: [String]? = nil,
        subjects: [OscalObservationSubject]? = nil,
        relevantEvidence: [OscalObservationRelevantEvidence]? = nil,
        collected: String,
        props: [OscalProp]? = nil,
        links: [OscalLink]? = nil,
        remarks: String? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.description = description
        self.methods = methods
        self.types = types
        self.subjects = subjects
        self.relevantEvidence = relevantEvidence
        self.collected = collected
        self.props = props
        self.links = links
        self.remarks = remarks
    }

    // Convenience: was this observation tagged as elevated by the
    // emitter? Detected via a known prop name. Used in lieu of the
    // observation-side `related-risks` field which OSCAL puts on the
    // risk side of the graph (risk.related-observations).
    public var isElevated: Bool {
        (props ?? []).contains { $0.name == "elevated-severity" && $0.value == "true" }
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case description
        case methods
        case types
        case subjects
        case relevantEvidence = "relevant-evidence"
        case collected
        case props
        case links
        case remarks
    }
}

/// `reviewed-controls` is required at every Assessment Result by OSCAL.
/// We declare "include-all" because the AR is generated from the
/// AuditRecord stream, which transitively covers every control mapped
/// in oscal/component-definition.json — there's no per-result subset.
public struct OscalControlSelection: Codable, Equatable {
    public let includeAll: OscalIncludeAll?

    public init(includeAll: OscalIncludeAll? = OscalIncludeAll()) {
        self.includeAll = includeAll
    }

    enum CodingKeys: String, CodingKey {
        case includeAll = "include-all"
    }
}

public struct OscalIncludeAll: Codable, Equatable {
    public init() {}
}

public struct OscalReviewedControls: Codable, Equatable {
    public let description: String?
    public let controlSelections: [OscalControlSelection]

    public init(description: String? = nil, controlSelections: [OscalControlSelection]) {
        self.description = description
        self.controlSelections = controlSelections
    }

    enum CodingKeys: String, CodingKey {
        case description
        case controlSelections = "control-selections"
    }
}

public struct OscalAssessmentResult: Codable, Equatable {
    public var uuid: String
    public var title: String
    public var description: String
    public var start: String
    public var end: String?
    public var reviewedControls: OscalReviewedControls
    public var observations: [OscalObservation]

    public init(
        uuid: String,
        title: String,
        description: String,
        start: String,
        end: String? = nil,
        reviewedControls: OscalReviewedControls = OscalReviewedControls(
            description: "All controls implemented by MCP-MacOSControl (see oscal/component-definition.json). The AR is generated from the STORY-024 AuditRecord stream, which transitively covers every control mapped there; the include-all selection reflects this scope.",
            controlSelections: [OscalControlSelection()]
        ),
        observations: [OscalObservation]
    ) {
        self.uuid = uuid
        self.title = title
        self.description = description
        self.start = start
        self.end = end
        self.reviewedControls = reviewedControls
        self.observations = observations
    }

    enum CodingKeys: String, CodingKey {
        case uuid, title, description, start, end
        case reviewedControls = "reviewed-controls"
        case observations
    }
}

public struct OscalImportAp: Codable, Equatable {
    public let href: String
    public let remarks: String?

    public init(href: String, remarks: String? = nil) {
        self.href = href
        self.remarks = remarks
    }
}

public struct OscalAssessmentResultsBody: Codable, Equatable {
    public var uuid: String
    public var metadata: OscalMetadata
    public var importAp: OscalImportAp
    public var results: [OscalAssessmentResult]

    public init(uuid: String, metadata: OscalMetadata, importAp: OscalImportAp, results: [OscalAssessmentResult]) {
        self.uuid = uuid
        self.metadata = metadata
        self.importAp = importAp
        self.results = results
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case metadata
        case importAp = "import-ap"
        case results
    }
}

public struct OscalAssessmentResultsDocument: Codable, Equatable {
    public var assessmentResults: OscalAssessmentResultsBody

    public init(assessmentResults: OscalAssessmentResultsBody) {
        self.assessmentResults = assessmentResults
    }

    enum CodingKeys: String, CodingKey {
        case assessmentResults = "assessment-results"
    }

    // MARK: - Convenience

    public var observations: [OscalObservation] {
        assessmentResults.results.first?.observations ?? []
    }

    // MARK: - Disk I/O

    public static func load(from url: URL) throws -> OscalAssessmentResultsDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(OscalAssessmentResultsDocument.self, from: data)
    }

    /// Returns the existing AR document at `url`, or — if the file does
    /// not exist — a freshly minted document with the documented metadata.
    /// Used by `oscal-emit` so first-run is the same code path as later
    /// runs.
    public static func loadOrCreate(
        at url: URL,
        metadataTitle: String = "MCP-MacOSControl Continuous Monitoring Assessment Results",
        documentUuid: String = "22222222-0000-4000-8000-0000000000ab",
        resultUuid: String = "33333333-0000-4000-8000-0000000000ac",
        now: Date = Date()
    ) throws -> OscalAssessmentResultsDocument {
        if FileManager.default.fileExists(atPath: url.path) {
            return try load(from: url)
        }
        let ts = OscalAssessmentResultsDocument.iso8601(now)
        return OscalAssessmentResultsDocument(
            assessmentResults: OscalAssessmentResultsBody(
                uuid: documentUuid,
                metadata: OscalMetadata(
                    title: metadataTitle,
                    lastModified: ts,
                    version: "1.0.0",
                    oscalVersion: "1.1.2",
                    parties: nil
                ),
                importAp: OscalImportAp(
                    href: "tbd-by-assessor.json",
                    remarks: "Assessor-authored Assessment Plan; system owner emits Observations only. See STORY-037 §9 for the rationale (Observations vs. Findings)."
                ),
                results: [
                    OscalAssessmentResult(
                        uuid: resultUuid,
                        title: "Continuous monitoring observations from the AuditRecord stream",
                        description: "Observations generated by oscal-emit from STORY-024 AuditRecord events. One observation per input record. Append-only: prior observations are never modified.",
                        start: ts,
                        observations: []
                    )
                ]
            )
        )
    }

    /// Returns a new document with `new` appended to the first result's
    /// observations array. Updates `metadata.last-modified` to `now`.
    /// Does NOT touch any pre-existing observation's content.
    public func appending(observations new: [OscalObservation], now: Date = Date()) -> OscalAssessmentResultsDocument {
        var body = self.assessmentResults
        guard !body.results.isEmpty else {
            return self
        }
        let ts = OscalAssessmentResultsDocument.iso8601(now)
        body.results[0].observations.append(contentsOf: new)
        body.metadata = OscalMetadata(
            title: body.metadata.title,
            lastModified: ts,
            version: body.metadata.version,
            oscalVersion: body.metadata.oscalVersion,
            parties: body.metadata.parties
        )
        if body.results[0].end == nil || (OscalAssessmentResultsDocument.parse(body.results[0].end ?? "") ?? .distantPast) < now {
            body.results[0].end = ts
        }
        return OscalAssessmentResultsDocument(assessmentResults: body)
    }

    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Timestamps

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    public static func iso8601(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    public static func parse(_ s: String) -> Date? {
        isoFormatter.date(from: s)
    }
}

// MARK: - Empty-doc factory

extension OscalAssessmentResultsDocument {
    /// Convenience for tests — an empty AR doc with deterministic IDs.
    public static var empty: OscalAssessmentResultsDocument {
        let ts = "2026-01-01T00:00:00.000Z"
        return OscalAssessmentResultsDocument(
            assessmentResults: OscalAssessmentResultsBody(
                uuid: "22222222-0000-4000-8000-0000000000ab",
                metadata: OscalMetadata(
                    title: "MCP-MacOSControl Continuous Monitoring Assessment Results",
                    lastModified: ts,
                    version: "1.0.0",
                    oscalVersion: "1.1.2",
                    parties: nil
                ),
                importAp: OscalImportAp(href: "tbd-by-assessor.json", remarks: "Assessor-authored."),
                results: [
                    OscalAssessmentResult(
                        uuid: "33333333-0000-4000-8000-0000000000ac",
                        title: "Continuous monitoring observations from the AuditRecord stream",
                        description: "Test seed.",
                        start: ts,
                        observations: []
                    )
                ]
            )
        )
    }
}
