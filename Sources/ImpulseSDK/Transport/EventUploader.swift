//
//  EventUploader.swift
//  ImpulseSDK
//

import Foundation

/// Periodically drains the `EventStore` and POSTs batches to the ingestion
/// endpoint. Transient failures leave steps queued for retry; permanent
/// rejections (4xx) drop the batch so one bad payload can't wedge the queue.
actor EventUploader {
    private enum UploadError: Error {
        case transient(statusCode: Int?)
        case permanent(statusCode: Int)
    }

    static let sdkVersion = "0.2.0"

    private let configuration: ImpulseConfiguration
    private let store: EventStore
    private let logger: ImpulseLogger
    private let urlSession: URLSession
    private let encoder: JSONEncoder

    private var context: ClientContext?
    private var flushTask: Task<Void, Never>?
    private var isFlushing = false

    init(
        configuration: ImpulseConfiguration,
        store: EventStore,
        logger: ImpulseLogger,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.store = store
        self.logger = logger
        self.urlSession = urlSession

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
    }

    func updateContext(_ context: ClientContext) {
        self.context = context
    }

    func start() {
        guard flushTask == nil else { return }
        let interval = configuration.flushInterval
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await self?.flush()
            }
        }
    }

    func stop() {
        flushTask?.cancel()
        flushTask = nil
    }

    func flush() async {
        guard !isFlushing, let context else { return }
        isFlushing = true
        defer { isFlushing = false }

        while true {
            let batch = await store.nextBatch(limit: configuration.flushBatchSize)
            guard !batch.isEmpty else { return }
            let ids = batch.map(\.id)

            do {
                try await send(batch, context: context)
                await store.confirm(ids)
                logger.debug("Uploaded \(batch.count) steps")
            } catch UploadError.permanent(let status) {
                // The server refused the payload; retrying would loop forever.
                await store.confirm(ids)
                logger.error("Batch rejected with status \(status); dropped \(batch.count) steps")
            } catch {
                await store.release(ids)
                logger.info("Upload failed, will retry: \(error)")
                return
            }
        }
    }

    private func send(_ steps: [JourneyStep], context: ClientContext) async throws {
        let batch = EventBatch(
            batchId: UUID().uuidString,
            sentAt: Date(),
            sdkVersion: Self.sdkVersion,
            platform: "ios",
            anonymousId: context.anonymousId,
            userId: context.userId,
            device: context.device,
            steps: steps
        )

        var request = URLRequest(url: configuration.endpoint.appendingPathComponent("v1/journeys"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Impulse-Api-Key")
        request.setValue(Self.sdkVersion, forHTTPHeaderField: "X-Impulse-SDK-Version")
        request.httpBody = try encoder.encode(batch)

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.transient(statusCode: nil)
        }
        switch http.statusCode {
        case 200..<300:
            return
        case 408, 429, 500...:
            throw UploadError.transient(statusCode: http.statusCode)
        default:
            throw UploadError.permanent(statusCode: http.statusCode)
        }
    }
}
