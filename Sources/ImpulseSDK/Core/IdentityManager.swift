//
//  IdentityManager.swift
//  ImpulseSDK
//

import Foundation

/// Persists the anonymous device identity and the customer-provided user id
/// so customer support can look up a specific user's sessions.
@MainActor
final class IdentityManager {
    private enum Keys {
        static let anonymousId = "com.impulse.sdk.anonymousId"
        static let userId = "com.impulse.sdk.userId"
    }

    private let defaults: UserDefaults

    private(set) var anonymousId: String
    private(set) var userId: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let existing = defaults.string(forKey: Keys.anonymousId) {
            anonymousId = existing
        } else {
            anonymousId = UUID().uuidString
            defaults.set(anonymousId, forKey: Keys.anonymousId)
        }
        userId = defaults.string(forKey: Keys.userId)
    }

    func identify(userId: String) {
        self.userId = userId
        defaults.set(userId, forKey: Keys.userId)
    }

    /// Clears the user id and rotates the anonymous id (e.g. on logout).
    func reset() {
        userId = nil
        defaults.removeObject(forKey: Keys.userId)
        anonymousId = UUID().uuidString
        defaults.set(anonymousId, forKey: Keys.anonymousId)
    }
}
