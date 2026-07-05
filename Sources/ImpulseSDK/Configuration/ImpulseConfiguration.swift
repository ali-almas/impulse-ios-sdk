//
//  ImpulseConfiguration.swift
//  ImpulseSDK
//

import Foundation

/// Signals the SDK may capture automatically. All auto-capture is opt-in;
/// by default only manually tracked steps are recorded.
public struct AutoCaptureOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// UIKit screen opens/closes via `viewDidAppear`/`viewDidDisappear`.
    public static let screens = AutoCaptureOptions(rawValue: 1 << 0)
    /// Taps and value changes on UIKit controls (buttons, switches, etc.).
    public static let actions = AutoCaptureOptions(rawValue: 1 << 1)
    /// Scroll-depth milestones (25/50/75/100%) on scroll views.
    public static let scrolls = AutoCaptureOptions(rawValue: 1 << 2)

    public static let all: AutoCaptureOptions = [.screens, .actions, .scrolls]
}

public enum LogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info
    case warning
    case error
    case none

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ImpulseConfiguration: Sendable {
    /// Base URL of the ingestion service (your deployment of the
    /// open-source Impulse web platform). Batches are POSTed to
    /// `{endpoint}/v1/journeys`.
    public var endpoint: URL
    /// Optional API key, sent as `X-Impulse-Api-Key` when set. Self-hosted
    /// deployments without authentication can omit it.
    public var apiKey: String?
    /// Which signals to capture automatically. Empty (manual tracking only)
    /// by default — enable explicitly, e.g. `.all` or `[.screens, .scrolls]`.
    public var autoCapture: AutoCaptureOptions
    /// When auto-capturing screens, only track view controllers conforming
    /// to `ImpulseTrackable` instead of every non-system controller.
    public var autoCaptureOnlyTrackableScreens: Bool
    /// Inactivity interval after which a new session (and journey) begins.
    public var sessionTimeout: TimeInterval
    /// How often queued steps are uploaded.
    public var flushInterval: TimeInterval
    /// Steps per upload request; reaching this count also triggers a flush.
    public var flushBatchSize: Int
    /// Cap on locally queued steps; oldest are dropped beyond this.
    public var maxQueuedSteps: Int
    public var logLevel: LogLevel

    public init(
        endpoint: URL,
        apiKey: String? = nil,
        autoCapture: AutoCaptureOptions = [],
        autoCaptureOnlyTrackableScreens: Bool = false,
        sessionTimeout: TimeInterval = 30 * 60,
        flushInterval: TimeInterval = 30,
        flushBatchSize: Int = 50,
        maxQueuedSteps: Int = 10_000,
        logLevel: LogLevel = .warning
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.autoCapture = autoCapture
        self.autoCaptureOnlyTrackableScreens = autoCaptureOnlyTrackableScreens
        self.sessionTimeout = sessionTimeout
        self.flushInterval = flushInterval
        self.flushBatchSize = flushBatchSize
        self.maxQueuedSteps = maxQueuedSteps
        self.logLevel = logLevel
    }
}
