import Foundation
import CoreGraphics

// STORY-010 — Agent Interaction Hierarchy Router
//
// Shared vocabulary for the four-layer fallback router. A `SmartInteractInput`
// states *intent* (the agent's goal); the router translates it into per-layer
// `TargetSpec`s and asks each `InteractionLayer` to `attempt` it, recording the
// ordered `DecisionLogEntry` trail regardless of outcome.

/// The two intents v1 supports. Drag/scroll/select are deliberately out of
/// scope (Three Amigos Q4) — the protocol is intent-generic so they are
/// additive later without a router redesign.
public enum InteractionIntent: String, Sendable, CaseIterable {
    case click
    case type
}

/// Intent-first input vocabulary (Three Amigos Q5). The router owns the
/// translation into per-layer tool inputs so the agent's prompt stays stable
/// while layer implementations evolve.
public struct SmartInteractInput {
    public let intent: InteractionIntent
    public let targetDescription: String?
    /// Bundle id or human name. Used for both AX scoping and registry lookup.
    public let application: String?
    public let coordinates: CGPoint?
    /// Required when `intent == .type`.
    public let value: String?
    /// Per-call layer-skip override (Three Amigos Q6). Layer names, e.g.
    /// `["coordinate_fallback"]`. Default: no skips.
    public let skipLayers: [String]

    public init(
        intent: InteractionIntent,
        targetDescription: String? = nil,
        application: String? = nil,
        coordinates: CGPoint? = nil,
        value: String? = nil,
        skipLayers: [String] = []
    ) {
        self.intent = intent
        self.targetDescription = targetDescription
        self.application = application
        self.coordinates = coordinates
        self.value = value
        self.skipLayers = skipLayers
    }
}

/// What the router hands a single layer for one attempt.
public struct TargetSpec {
    public let description: String?
    public let application: String?
    public let coordinates: CGPoint?
    public let value: String?

    public init(
        description: String? = nil,
        application: String? = nil,
        coordinates: CGPoint? = nil,
        value: String? = nil
    ) {
        self.description = description
        self.application = application
        self.coordinates = coordinates
        self.value = value
    }
}

/// A layer's verdict for one attempt.
///
/// - `succeeded`: the action dispatched. `confidence` is the layer's *baseline*;
///   the router applies the prior-failure decay (Three Amigos Q2).
/// - `skipped`: the layer was not applicable (registry said no, missing
///   prerequisite such as coordinates, system-wide AX permission missing).
///   Skips are *configuration*, not runtime failure (Three Amigos Q3).
/// - `failed`: an attempt was actually made and the underlying tool returned a
///   structured error. Fails are *runtime* (Three Amigos Q3).
public enum LayerOutcome: Sendable, Equatable {
    case succeeded(method: String, confidence: Double)
    case skipped(reason: String)
    case failed(errorCode: String, message: String)
}

public protocol InteractionLayer {
    /// Stable identifier surfaced in `decision_log`, e.g. `"ax_semantic"`.
    var name: String { get }
    /// Which registry capability flag governs this layer. The router reads it
    /// from `CapabilitiesResult` to decide registry-driven skips. `nil` for the
    /// coordinate fallback — it is the ultimate last resort and is never
    /// registry-skipped.
    var registryFlag: KeyPath<CapabilitiesResult, CapabilityFlag>? { get }
    /// Human label for the governing flag, used in the skip `reason` string
    /// (e.g. `"ax_supported"`). `nil` when `registryFlag` is `nil`.
    var registryFlagName: String? { get }
    func attempt(_ intent: InteractionIntent, target: TargetSpec) async -> LayerOutcome
}

public enum DecisionOutcome: String, Sendable, Equatable {
    case succeeded
    case skipped
    case failed
}

/// One ordered audit entry. Always present even when the first layer succeeds
/// (Definition of Done — decision log invariants).
public struct DecisionLogEntry {
    public let layer: String
    public let attempted: Bool
    public let outcome: DecisionOutcome
    public let reason: String
    public let elapsedMs: Int
    public var metadata: [String: String]

    public init(
        layer: String,
        attempted: Bool,
        outcome: DecisionOutcome,
        reason: String,
        elapsedMs: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.layer = layer
        self.attempted = attempted
        self.outcome = outcome
        self.reason = reason
        self.elapsedMs = elapsedMs
        self.metadata = metadata
    }

    /// Ergonomic init — `attempted` is derived (`skipped` ⇒ not attempted).
    public init(layer: String, outcome: DecisionOutcome, reason: String) {
        self.init(
            layer: layer,
            attempted: outcome != .skipped,
            outcome: outcome,
            reason: reason)
    }

    /// Serialized shape for the MCP response / error details.
    public var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "layer": layer,
            "attempted": attempted,
            "outcome": outcome.rawValue,
            "reason": reason,
            "elapsed_ms": elapsedMs
        ]
        if !metadata.isEmpty { dict["metadata"] = metadata }
        return dict
    }
}

/// The router's verdict. On success `isError == false` and
/// `interactionMethod`/`confidence` are meaningful; on exhaustion `isError ==
/// true`, `errorCode == "all_layers_failed"`, and `details` carries the log +
/// retry suggestions.
public struct RouterResult {
    public let interactionMethod: String
    public let confidence: Double
    public let decisionLog: [DecisionLogEntry]
    public let result: [String: String]
    public let isError: Bool
    public let errorCode: String?
    public let details: [String: Any]

    public init(
        interactionMethod: String,
        confidence: Double,
        decisionLog: [DecisionLogEntry],
        result: [String: String] = [:],
        isError: Bool = false,
        errorCode: String? = nil,
        details: [String: Any] = [:]
    ) {
        self.interactionMethod = interactionMethod
        self.confidence = confidence
        self.decisionLog = decisionLog
        self.result = result
        self.isError = isError
        self.errorCode = errorCode
        self.details = details
    }

    /// Ergonomic success init.
    public init(method: String, confidence: Double, decisionLog: [DecisionLogEntry]) {
        self.init(
            interactionMethod: method,
            confidence: confidence,
            decisionLog: decisionLog)
    }
}
