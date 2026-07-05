//
//  ActionAutoCapture.swift
//  ImpulseSDK
//

import UIKit
import ObjectiveC.runtime

/// Swizzles `UIApplication.sendAction` to record control interactions.
/// Installed only when `AutoCaptureOptions.actions` is enabled.
@MainActor
enum ActionAutoCapture {
    private static var installed = false
    /// Suppresses floods from continuous controls (sliders, repeated taps).
    private static var lastReport: [ObjectIdentifier: Date] = [:]
    private static let throttleInterval: TimeInterval = 0.5

    static func install() {
        guard !installed else { return }
        installed = true

        guard
            let original = class_getInstanceMethod(
                UIApplication.self,
                #selector(UIApplication.sendAction(_:to:from:for:))
            ),
            let swizzled = class_getInstanceMethod(
                UIApplication.self,
                #selector(UIApplication.impulse_sendAction(_:to:from:for:))
            )
        else { return }
        method_exchangeImplementations(original, swizzled)
    }

    static func handle(action: Selector, sender: Any?) {
        guard
            let client = ImpulseSDK.client,
            client.isEnabled,
            client.configuration.autoCapture.contains(.actions),
            let sender = sender as? NSObject,
            let descriptor = describe(sender: sender, action: action)
        else { return }

        guard !isThrottled(sender) else { return }

        var properties: [String: PropertyValue] = ["control_type": .string(descriptor.controlType)]
        for (key, value) in descriptor.properties {
            properties[key] = value
        }
        client.tracker.action(name: descriptor.name, properties: properties)
    }

    private struct ActionDescriptor {
        let name: String
        let controlType: String
        var properties: [String: PropertyValue] = [:]
    }

    private static func describe(sender: NSObject, action: Selector) -> ActionDescriptor? {
        switch sender {
        case let button as UIButton:
            let label = button.currentTitle
                ?? button.accessibilityLabel
                ?? NSStringFromSelector(action)
            return ActionDescriptor(name: label, controlType: "button")

        case let toggle as UISwitch:
            let label = toggle.accessibilityLabel ?? NSStringFromSelector(action)
            return ActionDescriptor(
                name: label,
                controlType: "switch",
                properties: ["value": .bool(toggle.isOn)]
            )

        case let segmented as UISegmentedControl:
            let index = segmented.selectedSegmentIndex
            let title = index != UISegmentedControl.noSegment
                ? segmented.titleForSegment(at: index)
                : nil
            return ActionDescriptor(
                name: segmented.accessibilityLabel ?? title ?? NSStringFromSelector(action),
                controlType: "segmented_control",
                properties: ["selected": .string(title ?? String(index))]
            )

        case let slider as UISlider:
            let label = slider.accessibilityLabel ?? NSStringFromSelector(action)
            return ActionDescriptor(
                name: label,
                controlType: "slider",
                properties: ["value": .double(Double(slider.value))]
            )

        case let item as UIBarButtonItem:
            let label = item.title ?? item.accessibilityLabel ?? NSStringFromSelector(action)
            return ActionDescriptor(name: label, controlType: "bar_button")

        case is UITextField, is UITextView:
            // Never capture text input; it is both noisy and sensitive.
            return nil

        default:
            return nil
        }
    }

    private static func isThrottled(_ sender: NSObject, now: Date = Date()) -> Bool {
        let key = ObjectIdentifier(sender)
        if let last = lastReport[key], now.timeIntervalSince(last) < throttleInterval {
            return true
        }
        if lastReport.count > 100 {
            lastReport.removeAll()
        }
        lastReport[key] = now
        return false
    }
}

extension UIApplication {
    @objc fileprivate func impulse_sendAction(
        _ action: Selector,
        to target: Any?,
        from sender: Any?,
        for event: UIEvent?
    ) -> Bool {
        ActionAutoCapture.handle(action: action, sender: sender)
        return impulse_sendAction(action, to: target, from: sender, for: event)
    }
}
