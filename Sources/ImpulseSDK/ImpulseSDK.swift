// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

@MainActor
public enum ImpulseSDK {
    public static func start() {
        UIViewControllerSwizzler.swizzle()
    }
    
    public static func stop() {
        
    }
}

extension ImpulseSDK {
    public static func onlyAllowTrackableScreens() {
        
    }
}
