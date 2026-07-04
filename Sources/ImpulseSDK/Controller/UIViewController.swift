//
//  UIViewController.swift
//  ImpulseSDK
//
//  Created by Ali Almasli on 05.07.26.
//

import UIKit
import ObjectiveC.runtime
import SwiftUI

@MainActor
final class UIViewControllerSwizzler {
    private static var hasSwizzled = false
    
    static func swizzle() {
        guard !hasSwizzled else {
            return
        }
        
        hasSwizzled = true
        
        UIViewController.startTracking()
    }
}

extension UIViewController {
    static func startTracking() {
        guard self == UIViewController.self else { return }

        let originalAppear = class_getInstanceMethod(
            UIViewController.self,
            #selector(viewDidAppear(_:))
        )!

        let swizzledAppear = class_getInstanceMethod(
            UIViewController.self,
            #selector(swizzled_viewDidAppear(_:))
        )!

        method_exchangeImplementations(originalAppear, swizzledAppear)

        let originalDisappear = class_getInstanceMethod(
            UIViewController.self,
            #selector(viewDidDisappear(_:))
        )!

        let swizzledDisappear = class_getInstanceMethod(
            UIViewController.self,
            #selector(swizzled_viewDidDisappear(_:))
        )!

        method_exchangeImplementations(originalDisappear, swizzledDisappear)
    }

    @objc private func swizzled_viewDidAppear(_ animated: Bool) {
        swizzled_viewDidAppear(animated)
        
        // Ignore SwiftUI hosting controllers
        if self is UIHostingController<AnyView> {
            return
        }
        
        if let trackable = self as? Trackable {
            print("OPENED: \(trackable.screenName)")
        } else {
            print("OPENED: \(type(of: self))")
        }
    }
    
    @objc private func swizzled_viewDidDisappear(_ animated: Bool) {
        swizzled_viewDidDisappear(animated)
        
        // Ignore SwiftUI hosting controllers
        if self is UIHostingController<AnyView> {
            return
        }
        
        if let trackable = self as? Trackable {
            print("CLOSED: \(trackable.screenName)")
        } else {
            print("CLOSED: \(type(of: self))")
        }
    }
}
