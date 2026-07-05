//
//  EventStore.swift
//  ImpulseSDK
//

import Foundation

/// Disk-backed queue of journey steps. Steps survive app kills and are only
/// removed after the server confirms receipt.
actor EventStore {
    private var queue: [JourneyStep] = []
    private var inFlight: Set<String> = []
    private let maxQueued: Int
    private let fileURL: URL
    private let logger: ImpulseLogger
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(maxQueued: Int, logger: ImpulseLogger, directory: URL? = nil) {
        self.maxQueued = maxQueued
        self.logger = logger

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let baseDirectory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImpulseSDK", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        fileURL = baseDirectory.appendingPathComponent("journey-queue.json")

        if let data = try? Data(contentsOf: fileURL),
           let restored = try? decoder.decode([JourneyStep].self, from: data) {
            queue = restored
        }
    }

    /// Appends a step and returns the number of steps awaiting upload.
    @discardableResult
    func append(_ step: JourneyStep) -> Int {
        queue.append(step)
        if queue.count > maxQueued {
            let overflow = queue.count - maxQueued
            let dropped = queue.prefix(overflow).filter { !inFlight.contains($0.id) }
            queue.removeAll { step in dropped.contains { $0.id == step.id } }
            if !dropped.isEmpty {
                logger.warning("Dropped \(dropped.count) oldest steps (queue full)")
            }
        }
        persist()
        return queue.count - inFlight.count
    }

    func pendingCount() -> Int {
        queue.count - inFlight.count
    }

    /// Reserves up to `limit` steps for upload.
    func nextBatch(limit: Int) -> [JourneyStep] {
        let batch = queue.lazy
            .filter { !self.inFlight.contains($0.id) }
            .prefix(limit)
        let steps = Array(batch)
        inFlight.formUnion(steps.map(\.id))
        return steps
    }

    /// Permanently removes steps that were accepted (or rejected) by the server.
    func confirm(_ ids: [String]) {
        let idSet = Set(ids)
        queue.removeAll { idSet.contains($0.id) }
        inFlight.subtract(idSet)
        persist()
    }

    /// Returns reserved steps to the queue after a transient upload failure.
    func release(_ ids: [String]) {
        inFlight.subtract(ids)
    }

    private func persist() {
        do {
            let data = try encoder.encode(queue)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to persist queue: \(error)")
        }
    }
}
