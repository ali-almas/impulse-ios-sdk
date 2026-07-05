//
//  EventBatch.swift
//  ImpulseSDK
//

import Foundation
import UIKit

/// Static device and app metadata sent with every batch.
public struct DeviceInfo: Codable, Equatable, Sendable {
    public let model: String
    public let systemName: String
    public let systemVersion: String
    public let appVersion: String
    public let appBuild: String
    public let bundleId: String
    public let locale: String

    enum CodingKeys: String, CodingKey {
        case model
        case systemName = "system_name"
        case systemVersion = "system_version"
        case appVersion = "app_version"
        case appBuild = "app_build"
        case bundleId = "bundle_id"
        case locale
    }

    @MainActor
    static func current() -> DeviceInfo {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        let info = Bundle.main.infoDictionary
        return DeviceInfo(
            model: machine.isEmpty ? UIDevice.current.model : machine,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info?["CFBundleVersion"] as? String ?? "unknown",
            bundleId: Bundle.main.bundleIdentifier ?? "unknown",
            locale: Locale.current.identifier
        )
    }
}

/// Identity and device context attached to uploads. Rebuilt whenever the
/// user is identified or reset.
struct ClientContext: Sendable {
    var anonymousId: String
    var userId: String?
    var device: DeviceInfo
}

/// The payload POSTed to the ingestion endpoint.
struct EventBatch: Codable, Sendable {
    let batchId: String
    let sentAt: Date
    let sdkVersion: String
    let platform: String
    let anonymousId: String
    let userId: String?
    let device: DeviceInfo
    let steps: [JourneyStep]

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case sentAt = "sent_at"
        case sdkVersion = "sdk_version"
        case platform
        case anonymousId = "anonymous_id"
        case userId = "user_id"
        case device
        case steps
    }
}
