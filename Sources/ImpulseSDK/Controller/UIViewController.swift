//
//  UIViewController.swift
//  ImpulseSDK
//
//  Created by Ali Almasli on 05.07.26.
//

import UIKit
import ObjectiveC.runtime

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

        print("OPENED: \(type(of: self))")
    }

    @objc private func swizzled_viewDidDisappear(_ animated: Bool) {
        swizzled_viewDidDisappear(animated)

        print("CLOSED: \(type(of: self))")
    }
}
