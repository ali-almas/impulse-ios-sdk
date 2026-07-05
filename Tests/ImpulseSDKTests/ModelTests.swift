//
//  ModelTests.swift
//  ImpulseSDKTests
//

import XCTest
@testable import ImpulseSDK

final class ModelTests: XCTestCase {
    func testPropertyValueLiteralsAndRoundtrip() throws {
        let properties: [String: PropertyValue] = [
            "plan": "pro",
            "count": 3,
            "ratio": 0.5,
            "active": true,
        ]

        let data = try JSONEncoder().encode(properties)
        let decoded = try JSONDecoder().decode([String: PropertyValue].self, from: data)

        XCTAssertEqual(decoded["plan"], .string("pro"))
        XCTAssertEqual(decoded["count"], .int(3))
        XCTAssertEqual(decoded["ratio"], .double(0.5))
        XCTAssertEqual(decoded["active"], .bool(true))
    }

    func testJourneyStepEncodesSnakeCaseKeys() throws {
        let step = JourneyStep(
            sessionId: "session-1",
            sequence: 4,
            type: .screenExit,
            name: "Checkout",
            screenInstanceId: "view-step-id",
            dwellMs: 1234,
            properties: ["from_push": true]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(step)) as? [String: Any]
        )

        XCTAssertEqual(json["session_id"] as? String, "session-1")
        XCTAssertEqual(json["screen_instance_id"] as? String, "view-step-id")
        XCTAssertEqual(json["dwell_ms"] as? Int, 1234)
        XCTAssertEqual(json["type"] as? String, "screen_exit")
        // User property keys must pass through untouched.
        let properties = try XCTUnwrap(json["properties"] as? [String: Any])
        XCTAssertEqual(properties["from_push"] as? Bool, true)
    }
}
