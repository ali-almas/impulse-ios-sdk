//
//  ImpulseSDK.swift
//  ImpulseSDK
//
//  Journey analytics for iOS: session-scoped user journeys with screen
//  dwell times, actions, scroll depth, and declared outcomes.
//

import UIKit

@MainActor
public enum Impulse {
    static private(set) var client: ImpulseClient?

    /// Initializes the SDK. Call once, as early as possible (e.g. in
    /// `application(_:didFinishLaunchingWithOptions:)` or the App init).
    ///
    /// Auto-capture is off unless explicitly enabled via
    /// `ImpulseConfiguration.autoCapture`.
    public static func configure(_ configuration: ImpulseConfiguration) {
        guard client == nil else {
            client?.logger.warning("Impulse.configure called more than once; ignoring")
            return
        }
        client = ImpulseClient(configuration: configuration)
    }

    // MARK: - Identity

    /// Associates journeys with your user id so customer support can look
    /// up a specific user's sessions in the dashboard.
    public static func identify(_ userId: String) {
        client?.identify(userId: userId)
    }

    /// Clears the user id and rotates the anonymous id (e.g. on logout).
    /// Also starts a new session.
    public static func reset() {
        client?.resetIdentity()
    }

    public static var anonymousId: String? {
        client?.identity.anonymousId
    }

    public static var userId: String? {
        client?.identity.userId
    }

    // MARK: - Journey tracking

    /// Records a screen visit start. Pair with `screenClosed(_:)` —
    /// dwell time is computed between the two.
    public static func screen(
        _ name: String,
        properties: [String: PropertyValue] = [:]
    ) {
        guardedClient()?.tracker.screenOpened(
            name: name,
            key: manualScreenKey(name),
            properties: properties
        )
    }

    /// Records a screen visit end and its dwell time.
    public static func screenClosed(_ name: String) {
        guardedClient()?.tracker.screenClosed(key: manualScreenKey(name))
    }

    /// Records a user action (tap, submit, toggle, …) as a journey step.
    public static func action(
        _ name: String,
        properties: [String: PropertyValue] = [:]
    ) {
        guardedClient()?.tracker.action(name: name, properties: properties)
    }

    /// Records how deep the user scrolled. `depth` is 0...1 of the content.
    public static func scroll(_ depth: Double, screen: String? = nil) {
        guardedClient()?.tracker.scroll(depth: depth, screenName: screen)
    }

    /// Records a custom journey step.
    public static func track(
        _ name: String,
        properties: [String: PropertyValue] = [:]
    ) {
        guardedClient()?.tracker.custom(name: name, properties: properties)
    }

    /// Declares the result of a named journey within the current session,
    /// e.g. `Impulse.outcome("checkout", .success)`. Sessions that never
    /// receive an outcome for a journey are treated as abandoned by the
    /// dashboard.
    public static func outcome(
        _ journey: String,
        _ outcome: JourneyOutcome,
        properties: [String: PropertyValue] = [:]
    ) {
        guardedClient()?.tracker.outcome(journey: journey, outcome: outcome, properties: properties)
    }

    // MARK: - Sessions

    /// The current session id, if configured.
    public static var sessionId: String? {
        client?.sessionManager.sessionId
    }

    /// Ends the current session and starts a fresh one (a fresh journey).
    public static func newSession() {
        guardedClient()?.tracker.startNewSession()
    }

    // MARK: - Control

    /// Uploads all queued steps now.
    public static func flush() {
        client?.flush()
    }

    /// Pauses or resumes all tracking. Queued steps are kept.
    public static func setEnabled(_ enabled: Bool) {
        client?.isEnabled = enabled
    }

    // MARK: - Internals

    private static func guardedClient() -> ImpulseClient? {
        guard let client, client.isEnabled else { return nil }
        return client
    }

    private static func manualScreenKey(_ name: String) -> AnyHashable {
        "impulse.manual.screen.\(name)"
    }
}
