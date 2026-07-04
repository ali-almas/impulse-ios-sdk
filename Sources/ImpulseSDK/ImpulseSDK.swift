// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

public enum ImpulseSDK {
    @MainActor public static func start() { UIViewController.startTracking() }
}
