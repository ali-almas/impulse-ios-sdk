//
//  SessionManagerTests.swift
//  ImpulseSDKTests
//

import XCTest
@testable import ImpulseSDK

@MainActor
final class SessionManagerTests: XCTestCase {
    func testSequenceIncrements() {
        let manager = SessionManager(timeout: 1800)
        XCTAssertEqual(manager.nextSequence(), 1)
        XCTAssertEqual(manager.nextSequence(), 2)
    }

    func testNoRotationWithinTimeout() {
        let start = Date()
        let manager = SessionManager(timeout: 1800, now: start)
        _ = manager.nextSequence(now: start)

        XCTAssertNil(manager.rotateIfNeeded(now: start.addingTimeInterval(1799)))
    }

    func testRotationAfterTimeout() {
        let start = Date()
        let manager = SessionManager(timeout: 1800, now: start)
        let originalId = manager.sessionId
        _ = manager.nextSequence(now: start.addingTimeInterval(60))

        let rotation = manager.rotateIfNeeded(now: start.addingTimeInterval(60 + 1801))

        XCTAssertNotNil(rotation)
        XCTAssertEqual(rotation?.endedSessionId, originalId)
        XCTAssertEqual(rotation?.durationMs, 60_000)
        XCTAssertEqual(rotation?.endSequence, 2)
        XCTAssertNotEqual(manager.sessionId, originalId)
        XCTAssertEqual(manager.nextSequence(), 1)
    }

    func testForcedRotation() {
        let manager = SessionManager(timeout: 1800)
        let originalId = manager.sessionId

        let rotation = manager.rotate()

        XCTAssertEqual(rotation.endedSessionId, originalId)
        XCTAssertNotEqual(manager.sessionId, originalId)
    }
}
