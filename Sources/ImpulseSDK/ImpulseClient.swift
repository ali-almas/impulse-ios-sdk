//
//  ImpulseClient.swift
//  ImpulseSDK
//

import UIKit

/// Wires together identity, sessions, journey tracking, storage, and upload.
/// Created once by `ImpulseSDK.configure(_:)`.
@MainActor
final class ImpulseClient {
    let configuration: ImpulseConfiguration
    let logger: ImpulseLogger
    let identity: IdentityManager
    let sessionManager: SessionManager
    let store: EventStore
    let uploader: EventUploader
    private(set) var tracker: JourneyTracker!

    var isEnabled = true

    init(configuration: ImpulseConfiguration) {
        self.configuration = configuration
        logger = ImpulseLogger(level: configuration.logLevel)
        identity = IdentityManager()
        sessionManager = SessionManager(timeout: configuration.sessionTimeout)
        store = EventStore(maxQueued: configuration.maxQueuedSteps, logger: logger)
        uploader = EventUploader(configuration: configuration, store: store, logger: logger)

        tracker = JourneyTracker(sessionManager: sessionManager, logger: logger) { [weak self] step in
            self?.enqueue(step)
        }

        pushContext()
        installAutoCapture()
        observeLifecycle()

        tracker.startSession()
        Task { [uploader] in
            await uploader.start()
        }
        logger.info("Impulse configured; session \(sessionManager.sessionId)")
    }

    // MARK: - Identity

    func identify(userId: String) {
        identity.identify(userId: userId)
        pushContext()
    }

    func resetIdentity() {
        identity.reset()
        pushContext()
        // A new person implies a new journey.
        tracker.startNewSession()
    }

    private func pushContext() {
        let context = ClientContext(
            anonymousId: identity.anonymousId,
            userId: identity.userId,
            device: DeviceInfo.current()
        )
        Task { [uploader] in
            await uploader.updateContext(context)
        }
    }

    // MARK: - Pipeline

    private func enqueue(_ step: JourneyStep) {
        guard isEnabled else { return }
        let batchSize = configuration.flushBatchSize
        Task { [store, uploader] in
            let pending = await store.append(step)
            if pending >= batchSize {
                await uploader.flush()
            }
        }
    }

    func flush() {
        Task { [uploader] in
            await uploader.flush()
        }
    }

    // MARK: - Auto capture

    private func installAutoCapture() {
        let options = configuration.autoCapture
        if options.contains(.screens) {
            ScreenAutoCapture.install()
        }
        if options.contains(.actions) {
            ActionAutoCapture.install()
        }
        if options.contains(.scrolls) {
            ScrollAutoCapture.install()
        }
    }

    // MARK: - App lifecycle

    private func observeLifecycle() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        // Ask for background time so the final flush can finish.
        let application = UIApplication.shared
        let holder = BackgroundTaskHolder()
        holder.taskId = application.beginBackgroundTask { [holder] in
            MainActor.assumeIsolated {
                holder.end(in: application)
            }
        }
        Task { [uploader] in
            await uploader.flush()
            await MainActor.run {
                holder.end(in: application)
            }
        }
    }

    @objc private func appWillEnterForeground() {
        tracker.resumeIfNeeded()
    }
}

@MainActor
private final class BackgroundTaskHolder {
    var taskId: UIBackgroundTaskIdentifier = .invalid

    func end(in application: UIApplication) {
        guard taskId != .invalid else { return }
        application.endBackgroundTask(taskId)
        taskId = .invalid
    }
}
