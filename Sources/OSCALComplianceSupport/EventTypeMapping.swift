// STORY-037 — Maps STORY-024 AuditRecord events into the OSCAL
// Observation shape expected by an assessor.
//
// One AuditRecord becomes one Observation. The mapping is keyed on
// (eventType, filterDisposition) because the same source event type
// (`applescript_execute`) means different things depending on whether
// the security filter let it through:
//
//   applescript_execute + allowed             → "applescript_executed"
//   applescript_execute + rejected_security   → "applescript_rejected"
//   applescript_execute + rejected_permission → "applescript_rejected"
//   menu_click                                → "click_menu_item_invoked"
//   menu_alternatives_lookup                  → "menu_alternatives_lookup"
//   chain_verification_failure                → "run_applescript_audit_chain_break"
//   administrative_force_rotate_unacked       → "administrative_force_rotate_unacked"
//
// The "control linkage" column is the assessor's primary handle for
// rolling Observations up into Findings — they map exactly to control
// IDs that exist in oscal/component-definition.json (STORY-022). When
// you add a new AuditEventType, add a mapping row here AND verify the
// referenced control IDs exist in the component definition; the drift
// tests cover the second half.
//
// Documented future event types (`rate_limit_exceeded`,
// `response_size_truncated`) live only in the assessment-results-mapping
// document. They are not in the AuditEventType enum today, so the
// emitter cannot produce them; when AuditRecorder learns to emit them,
// add cases here.

import Foundation
import MacOSControlLib

public struct EventTypeMapping {

    /// One mapping row. `controls` are lowercase 800-53 IDs (matching the
    /// component-definition naming). `elevated` marks chain-break-class
    /// events so the emitter populates the `risks` link and the
    /// downstream POA&M wire-up logic auto-opens a POA&M item.
    public struct Entry: Equatable {
        public let observationTitle: String
        public let methods: [String]
        public let controls: [String]
        public let elevated: Bool

        public init(observationTitle: String, methods: [String], controls: [String], elevated: Bool = false) {
            self.observationTitle = observationTitle
            self.methods = methods
            self.controls = controls
            self.elevated = elevated
        }
    }

    public init() {}

    public static let `default` = EventTypeMapping()

    /// Returns the mapping row for `record`, or nil for events we don't
    /// know how to map yet. The CLI logs unmapped event types and skips
    /// the record so a future schema bump doesn't fail-build retroactive
    /// runs over historical AuditRecord streams.
    public func entry(for record: AuditRecord) -> Entry? {
        switch (record.eventType, record.filterDisposition) {
        case (.applescriptExecute, .allowed):
            return Entry(
                observationTitle: "applescript_executed",
                methods: ["EXAMINE"],
                controls: ["au-2", "au-3", "cm-7"]
            )
        case (.applescriptExecute, .rejectedSecurity),
             (.applescriptExecute, .rejectedPermission):
            return Entry(
                observationTitle: "applescript_rejected",
                methods: ["EXAMINE"],
                controls: ["si-10", "cm-7"]
            )
        case (.applescriptExecute, .notApplicable):
            // Defensive: applescript_execute should never carry not_applicable
            // disposition. Treat it as a rejected event so it still produces an
            // auditable observation rather than silently skipping.
            return Entry(
                observationTitle: "applescript_rejected",
                methods: ["EXAMINE"],
                controls: ["si-10", "cm-7"]
            )

        case (.menuClick, _):
            return Entry(
                observationTitle: "click_menu_item_invoked",
                methods: ["EXAMINE"],
                controls: ["au-2", "au-3"]
            )
        case (.menuAlternativesLookup, _):
            return Entry(
                observationTitle: "menu_alternatives_lookup",
                methods: ["EXAMINE"],
                controls: ["au-2", "au-3"]
            )

        case (.chainVerificationFailure, _):
            return Entry(
                observationTitle: "run_applescript_audit_chain_break",
                methods: ["TEST"],
                controls: ["au-9"],
                elevated: true
            )

        case (.administrativeForceRotateUnacked, _):
            return Entry(
                observationTitle: "administrative_force_rotate_unacked",
                methods: ["EXAMINE"],
                controls: ["au-9", "au-11"]
            )
        }
    }

    /// All event-type rows we currently know how to map — used by tests
    /// to verify every AuditEventType has a row (catches missing cases
    /// at refactor time).
    public var knownEventTypes: [AuditEventType] {
        AuditEventType.allCases
    }
}
