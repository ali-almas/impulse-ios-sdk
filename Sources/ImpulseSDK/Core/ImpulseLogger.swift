//
//  ImpulseLogger.swift
//  ImpulseSDK
//

import Foundation

struct ImpulseLogger: Sendable {
    let level: LogLevel

    func debug(_ message: @autoclosure () -> String) {
        log(.debug, message())
    }

    func info(_ message: @autoclosure () -> String) {
        log(.info, message())
    }

    func warning(_ message: @autoclosure () -> String) {
        log(.warning, message())
    }

    func error(_ message: @autoclosure () -> String) {
        log(.error, message())
    }

    private func log(_ messageLevel: LogLevel, _ message: String) {
        guard messageLevel >= level, level != .none else { return }
        print("[Impulse] \(message)")
    }
}
