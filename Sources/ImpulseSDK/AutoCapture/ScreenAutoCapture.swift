//
//  ScreenAutoCapture.swift
//  ImpulseSDK
//

import UIKit
import ObjectiveC.runtime

/// Swizzles `viewDidAppear`/`viewDidDisappear` to record screen visits.
/// Installed only when `AutoCaptureOptions.screens` is enabled.
@MainActor
enum ScreenAutoCapture {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true

        swizzle(
            #selector(UIViewController.viewDidAppear(_:)),
            with: #selector(UIViewController.impulse_viewDidAppear(_:))
        )
        swizzle(
            #selector(UIViewController.viewDidDisappear(_:)),
            with: #selector(UIViewController.impulse_viewDidDisappear(_:))
        )
    }

    private static func swizzle(_ original: Selector, with swizzled: Selector) {
        guard
            let originalMethod = class_getInstanceMethod(UIViewController.self, original),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzled)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    static func handleAppear(_ viewController: UIViewController) {
        guard let client = activeClient(), shouldTrack(viewController, client: client) else { return }
        client.tracker.screenOpened(
            name: screenName(for: viewController),
            key: ObjectIdentifier(viewController)
        )
    }

    static func handleDisappear(_ viewController: UIViewController) {
        guard let client = activeClient() else { return }
        client.tracker.screenClosed(key: ObjectIdentifier(viewController))
    }

    private static func activeClient() -> ImpulseClient? {
        guard
            let client = ImpulseSDK.client,
            client.isEnabled,
            client.configuration.autoCapture.contains(.screens)
        else { return nil }
        return client
    }

    private static func screenName(for viewController: UIViewController) -> String {
        (viewController as? ImpulseTrackable)?.screenName
            ?? String(describing: type(of: viewController))
    }

    private static func shouldTrack(
        _ viewController: UIViewController,
        client: ImpulseClient
    ) -> Bool {
        if viewController is ImpulseTrackable { return true }
        if client.configuration.autoCaptureOnlyTrackableScreens { return false }

        // Containers manage children; the children are the real screens.
        if viewController is UINavigationController
            || viewController is UITabBarController
            || viewController is UISplitViewController
            || viewController is UIPageViewController {
            return false
        }

        // Skip UIKit/SwiftUI internals. SwiftUI screens should use the
        // `impulseTrackScreen` modifier instead of the hosting controller.
        let className = NSStringFromClass(type(of: viewController))
        if className.hasPrefix("_")
            || className.hasPrefix("UI")
            || className.hasPrefix("SwiftUI.")
            || className.contains("HostingController") {
            return false
        }
        return true
    }
}

extension UIViewController {
    @objc fileprivate func impulse_viewDidAppear(_ animated: Bool) {
        impulse_viewDidAppear(animated)
        ScreenAutoCapture.handleAppear(self)
    }

    @objc fileprivate func impulse_viewDidDisappear(_ animated: Bool) {
        impulse_viewDidDisappear(animated)
        ScreenAutoCapture.handleDisappear(self)
    }
}
