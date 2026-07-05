//
//  JourneyTrackerTests.swift
//  ImpulseSDKTests
//

import XCTest
@testable import ImpulseSDK

@MainActor
final class JourneyTrackerTests: XCTestCase {
    private var steps: [JourneyStep] = []
    private var tracker: JourneyTracker!

    /// XCTest's `setUp()` override stays nonisolated, so per-test setup
    /// happens here on the main actor instead.
    private func makeTracker() {
        steps = []
        tracker = JourneyTracker(
            sessionManager: SessionManager(timeout: 1800),
            logger: ImpulseLogger(level: .none)
        ) { [weak self] step in
            self?.steps.append(step)
        }
    }

    func testScreenDwellTime() {
        makeTracker()
        let opened = Date()
        tracker.screenOpened(name: "ScreenA", key: "a", now: opened)
        tracker.screenClosed(key: "a", now: opened.addingTimeInterval(2.5))

        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(steps[0].type, .screenView)
        XCTAssertEqual(steps[0].name, "ScreenA")
        XCTAssertEqual(steps[1].type, .screenExit)
        XCTAssertEqual(steps[1].dwellMs, 2500)
        XCTAssertEqual(steps[1].screenInstanceId, steps[0].id)
    }

    func testActionsCarryCurrentScreen() {
        makeTracker()
        tracker.screenOpened(name: "Checkout", key: "checkout")
        tracker.action(name: "pay_button")

        let action = steps.last
        XCTAssertEqual(action?.type, .action)
        XCTAssertEqual(action?.properties["screen"], .string("Checkout"))
    }

    func testOutcomeStep() {
        makeTracker()
        tracker.outcome(journey: "checkout", outcome: .failure, properties: ["reason": "card_declined"])

        let outcome = steps.last
        XCTAssertEqual(outcome?.type, .outcome)
        XCTAssertEqual(outcome?.name, "checkout")
        XCTAssertEqual(outcome?.properties["outcome"], .string("failure"))
        XCTAssertEqual(outcome?.properties["reason"], .string("card_declined"))
    }

    func testSequenceOrderingWithinSession() {
        makeTracker()
        tracker.startSession()
        tracker.screenOpened(name: "A", key: "a")
        tracker.action(name: "tap")

        let sequences = steps.map(\.sequence)
        XCTAssertEqual(sequences, Array(1...steps.count))
        XCTAssertEqual(Set(steps.map(\.sessionId)).count, 1)
    }

    func testStartNewSessionEmitsEndAndStart() {
        makeTracker()
        tracker.startSession()
        let firstSession = steps[0].sessionId

        tracker.startNewSession()

        let end = steps.first { $0.type == .sessionEnd }
        let starts = steps.filter { $0.type == .sessionStart }
        XCTAssertEqual(end?.sessionId, firstSession)
        XCTAssertEqual(starts.count, 2)
        XCTAssertNotEqual(starts.last?.sessionId, firstSession)
    }

    func testReopeningSameScreenClosesPreviousVisit() {
        makeTracker()
        let now = Date()
        tracker.screenOpened(name: "Feed", key: "feed", now: now)
        tracker.screenOpened(name: "Feed", key: "feed", now: now.addingTimeInterval(1))

        XCTAssertEqual(steps.map(\.type), [.screenView, .screenExit, .screenView])
        XCTAssertEqual(steps[1].dwellMs, 1000)
    }
}
