//
//  SessionManager.swift
//  ImpulseSDK
//

import Foundation

/// Owns the current session id, per-session step ordering, and rotation
/// after inactivity. A journey is scoped to one session.
@MainActor
final class SessionManager {
    struct Rotation {
        let endedSessionId: String
        let endedAt: Date
        let durationMs: Int
        /// Sequence number for the closing `session_end` step of the old session.
        let endSequence: Int
    }

    private(set) var sessionId: String
    private(set) var startedAt: Date
    private(set) var lastActivity: Date
    private var sequence = 0
    private let timeout: TimeInterval

    init(timeout: TimeInterval, now: Date = Date()) {
        self.timeout = timeout
        sessionId = UUID().uuidString
        startedAt = now
        lastActivity = now
    }

    /// Returns the next step sequence number and marks activity.
    func nextSequence(now: Date = Date()) -> Int {
        sequence += 1
        lastActivity = now
        return sequence
    }

    /// Rotates the session if the inactivity timeout elapsed.
    func rotateIfNeeded(now: Date = Date()) -> Rotation? {
        guard now.timeIntervalSince(lastActivity) > timeout else { return nil }
        return rotate(now: now)
    }

    /// Unconditionally starts a new session, returning details of the old one.
    func rotate(now: Date = Date()) -> Rotation {
        let rotation = Rotation(
            endedSessionId: sessionId,
            endedAt: lastActivity,
            durationMs: Int(lastActivity.timeIntervalSince(startedAt) * 1000),
            endSequence: sequence + 1
        )
        sessionId = UUID().uuidString
        startedAt = now
        lastActivity = now
        sequence = 0
        return rotation
    }
}
