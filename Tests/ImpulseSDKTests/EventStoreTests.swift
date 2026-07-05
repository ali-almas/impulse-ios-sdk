//
//  EventStoreTests.swift
//  ImpulseSDKTests
//

import XCTest
@testable import ImpulseSDK

final class EventStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("impulse-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeStep(_ name: String, sequence: Int = 1) -> JourneyStep {
        JourneyStep(sessionId: "s", sequence: sequence, type: .custom, name: name)
    }

    private func makeStore(maxQueued: Int = 100) -> EventStore {
        EventStore(
            maxQueued: maxQueued,
            logger: ImpulseLogger(level: .none),
            directory: directory
        )
    }

    func testBatchLifecycle() async {
        let store = makeStore()
        await store.append(makeStep("one"))
        await store.append(makeStep("two", sequence: 2))

        let batch = await store.nextBatch(limit: 10)
        XCTAssertEqual(batch.map(\.name), ["one", "two"])

        // Reserved steps are not handed out twice.
        let empty = await store.nextBatch(limit: 10)
        XCTAssertTrue(empty.isEmpty)

        // Released steps become available again.
        await store.release(batch.map(\.id))
        let retried = await store.nextBatch(limit: 10)
        XCTAssertEqual(retried.count, 2)

        await store.confirm(retried.map(\.id))
        let remaining = await store.pendingCount()
        XCTAssertEqual(remaining, 0)
    }

    func testPersistenceAcrossInstances() async {
        let first = makeStore()
        await first.append(makeStep("persisted"))

        let second = makeStore()
        let batch = await second.nextBatch(limit: 10)
        XCTAssertEqual(batch.map(\.name), ["persisted"])
    }

    func testQueueCapDropsOldest() async {
        let store = makeStore(maxQueued: 2)
        await store.append(makeStep("one"))
        await store.append(makeStep("two", sequence: 2))
        await store.append(makeStep("three", sequence: 3))

        let batch = await store.nextBatch(limit: 10)
        XCTAssertEqual(batch.map(\.name), ["two", "three"])
    }
}
