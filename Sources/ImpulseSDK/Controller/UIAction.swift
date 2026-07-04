//
//  UIAction.swift
//  ImpulseSDK
//
//  Created by Ali Almasli on 05.07.26.
//

import UIKit
import ObjectiveC.runtime

extension UIApplication {
    static func enableActionTracking() {
        guard
            let original = class_getInstanceMethod(
                UIApplication.self,
                #selector(sendAction(_:to:from:for:))
            ),
            let swizzled = class_getInstanceMethod(
                UIApplication.self,
                #selector(swizzled_sendAction(_:to:from:for:))
            )
        else {
            return
        }

        method_exchangeImplementations(original, swizzled)
    }

    @objc private func swizzled_sendAction(
        _ action: Selector,
        to target: Any?,
        from sender: Any?,
        for event: UIEvent?
    ) -> Bool {

        trackAction(
            action,
            target: target,
            sender: sender
        )

        return swizzled_sendAction(
            action,
            to: target,
            from: sender,
            for: event
        )
    }
    
    private func trackAction(
        _ action: Selector,
        target: Any?,
        sender: Any?
    ) {

        switch sender {

        case let button as UIButton:
            print("UIButton tapped")
            print(button.currentTitle ?? "")

        case is UISwitch:
            print("UISwitch changed")

        case is UISlider:
            print("UISlider changed")

        case is UISegmentedControl:
            print("Segment changed")

        case is UIBarButtonItem:
            print("Bar button tapped")

        default:
            print("Action: \(action)")
        }
    }
}
