//
//  JourneyTracker.swift
//  ImpulseSDK
//

import Foundation

/// Builds the ordered journey for the current session: screen visits with
/// dwell time, actions, scrolls, and declared journey outcomes.
@MainActor
final class JourneyTracker {
    private struct OpenScreen {
        let stepId: String
        let name: String
        let openedAt: Date
    }

    private let sessionManager: SessionManager
    private let logger: ImpulseLogger
    private let emit: (JourneyStep) -> Void

    private var openScreens: [AnyHashable: OpenScreen] = [:]
    /// The most recently opened screen; attached to actions and scrolls so
    /// the dashboard can place them inside the journey.
    private(set) var currentScreenName: String?

    init(
        sessionManager: SessionManager,
        logger: ImpulseLogger,
        emit: @escaping (JourneyStep) -> Void
    ) {
        self.sessionManager = sessionManager
        self.logger = logger
        self.emit = emit
    }

    // MARK: - Session

    func startSession() {
        record(type: .sessionStart, name: "session")
    }

    /// Called on foreground; rotates the session if the timeout elapsed.
    func resumeIfNeeded(now: Date = Date()) {
        if let rotation = sessionManager.rotateIfNeeded(now: now) {
            apply(rotation, now: now)
        }
    }

    /// Explicitly ends the current session and starts a fresh one.
    func startNewSession(now: Date = Date()) {
        apply(sessionManager.rotate(now: now), now: now)
    }

    // MARK: - Screens

    func screenOpened(
        name: String,
        key: AnyHashable,
        properties: [String: PropertyValue] = [:],
        now: Date = Date()
    ) {
        // A re-appear of a screen we already consider open (e.g. returning
        // from a pushed controller) starts a fresh visit.
        if openScreens[key] != nil {
            screenClosed(key: key, now: now)
        }
        let step = record(type: .screenView, name: name, properties: properties, now: now)
        openScreens[key] = OpenScreen(stepId: step.id, name: name, openedAt: now)
        currentScreenName = name
        logger.debug("Screen opened: \(name)")
    }

    func screenClosed(key: AnyHashable, now: Date = Date()) {
        guard let open = openScreens.removeValue(forKey: key) else { return }
        let dwellMs = max(0, Int(now.timeIntervalSince(open.openedAt) * 1000))
        record(
            type: .screenExit,
            name: open.name,
            screenInstanceId: open.stepId,
            dwellMs: dwellMs,
            now: now
        )
        logger.debug("Screen closed: \(open.name) after \(dwellMs)ms")
    }

    // MARK: - Steps

    func action(name: String, properties: [String: PropertyValue] = [:]) {
        record(type: .action, name: name, properties: attachScreen(to: properties))
    }

    func scroll(depth: Double, screenName: String? = nil) {
        var properties: [String: PropertyValue] = [:]
        properties["depth"] = .double(depth)
        if let screen = screenName ?? currentScreenName {
            properties["screen"] = .string(screen)
        }
        record(type: .scroll, name: "scroll", properties: properties)
    }

    func outcome(
        journey: String,
        outcome: JourneyOutcome,
        properties: [String: PropertyValue] = [:]
    ) {
        var properties = attachScreen(to: properties)
        properties["outcome"] = .string(outcome.rawValue)
        record(type: .outcome, name: journey, properties: properties)
        logger.info("Journey '\(journey)' marked \(outcome.rawValue)")
    }

    func custom(name: String, properties: [String: PropertyValue] = [:]) {
        record(type: .custom, name: name, properties: attachScreen(to: properties))
    }

    // MARK: - Internals

    @discardableResult
    private func record(
        type: JourneyStepType,
        name: String,
        properties: [String: PropertyValue] = [:],
        screenInstanceId: String? = nil,
        dwellMs: Int? = nil,
        now: Date = Date()
    ) -> JourneyStep {
        if let rotation = sessionManager.rotateIfNeeded(now: now) {
            apply(rotation, now: now)
        }
        let step = JourneyStep(
            sessionId: sessionManager.sessionId,
            sequence: sessionManager.nextSequence(now: now),
            type: type,
            name: name,
            timestamp: now,
            screenInstanceId: screenInstanceId,
            dwellMs: dwellMs,
            properties: properties
        )
        emit(step)
        return step
    }

    private func apply(_ rotation: SessionManager.Rotation, now: Date) {
        // Close out the old session with its real end time and duration.
        emit(JourneyStep(
            sessionId: rotation.endedSessionId,
            sequence: rotation.endSequence,
            type: .sessionEnd,
            name: "session",
            timestamp: rotation.endedAt,
            properties: ["duration_ms": .int(rotation.durationMs)]
        ))
        // Dwell measured across a session gap is meaningless; drop open visits.
        openScreens.removeAll()
        emit(JourneyStep(
            sessionId: sessionManager.sessionId,
            sequence: sessionManager.nextSequence(now: now),
            type: .sessionStart,
            name: "session",
            timestamp: now
        ))
        logger.info("Started new session \(sessionManager.sessionId)")
    }

    private func attachScreen(to properties: [String: PropertyValue]) -> [String: PropertyValue] {
        var properties = properties
        if properties["screen"] == nil, let screen = currentScreenName {
            properties["screen"] = .string(screen)
        }
        return properties
    }
}
