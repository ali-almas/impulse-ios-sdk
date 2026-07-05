//
//  JourneyStep.swift
//  ImpulseSDK
//

import Foundation

/// The kind of step within a user journey.
public enum JourneyStepType: String, Codable, Sendable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case screenView = "screen_view"
    case screenExit = "screen_exit"
    case action = "action"
    case scroll = "scroll"
    case outcome = "outcome"
    case custom = "custom"
}

/// The declared result of a named journey (e.g. a checkout flow).
/// Sessions that never receive an outcome are implicitly abandoned.
public enum JourneyOutcome: String, Codable, Sendable {
    case success
    case failure
}

/// A single, ordered step inside a session's journey.
///
/// Steps are append-only. A screen visit produces a `screen_view` step when it
/// appears and a `screen_exit` step (carrying `dwellMs` and referencing the
/// view step via `screenInstanceId`) when it disappears, so dwell time survives
/// mid-visit uploads and app kills.
public struct JourneyStep: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let sessionId: String
    /// Monotonic order of the step within its session.
    public let sequence: Int
    public let type: JourneyStepType
    /// Screen name, action name, or journey name depending on `type`.
    public let name: String
    public let timestamp: Date
    /// For `screen_exit` steps: the `id` of the matching `screen_view` step.
    public let screenInstanceId: String?
    /// For `screen_exit` steps: time spent on the screen, in milliseconds.
    public let dwellMs: Int?
    public let properties: [String: PropertyValue]

    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        sequence: Int,
        type: JourneyStepType,
        name: String,
        timestamp: Date = Date(),
        screenInstanceId: String? = nil,
        dwellMs: Int? = nil,
        properties: [String: PropertyValue] = [:]
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sequence = sequence
        self.type = type
        self.name = name
        self.timestamp = timestamp
        self.screenInstanceId = screenInstanceId
        self.dwellMs = dwellMs
        self.properties = properties
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case sequence
        case type
        case name
        case timestamp
        case screenInstanceId = "screen_instance_id"
        case dwellMs = "dwell_ms"
        case properties
    }
}
