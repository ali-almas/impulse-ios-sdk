//
//  ScrollAutoCapture.swift
//  ImpulseSDK
//

import UIKit
import ObjectiveC.runtime

/// Records scroll-depth milestones (25/50/75/100%) for scroll views on
/// screen. Installed only when `AutoCaptureOptions.scrolls` is enabled.
@MainActor
enum ScrollAutoCapture {
    private static var installed = false
    private nonisolated(unsafe) static var observerKey: UInt8 = 0

    static func install() {
        guard !installed else { return }
        installed = true

        guard
            let original = class_getInstanceMethod(
                UIScrollView.self,
                #selector(UIScrollView.didMoveToWindow)
            ),
            let swizzled = class_getInstanceMethod(
                UIScrollView.self,
                #selector(UIScrollView.impulse_didMoveToWindow)
            )
        else { return }
        method_exchangeImplementations(original, swizzled)
    }

    static func handleMovedToWindow(_ scrollView: UIScrollView) {
        guard scrollView.window != nil else {
            objc_setAssociatedObject(
                scrollView, &observerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return
        }
        guard
            let client = ImpulseSDK.client,
            client.isEnabled,
            client.configuration.autoCapture.contains(.scrolls),
            objc_getAssociatedObject(scrollView, &observerKey) == nil
        else { return }

        objc_setAssociatedObject(
            scrollView,
            &observerKey,
            ScrollDepthObserver(scrollView: scrollView),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

/// Watches one scroll view's content offset and reports each depth
/// milestone the first time the user reaches it.
@MainActor
private final class ScrollDepthObserver {
    private static let milestones: [Double] = [0.25, 0.5, 0.75, 1.0]

    private var observation: NSKeyValueObservation?
    private var reportedMilestone: Double = 0

    init(scrollView: UIScrollView) {
        observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            // Scroll KVO fires on the main thread for UI-driven scrolling.
            MainActor.assumeIsolated {
                self?.offsetChanged(scrollView)
            }
        }
    }

    private func offsetChanged(_ scrollView: UIScrollView) {
        let scrollableHeight = scrollView.contentSize.height
        // Ignore non-scrolling or barely scrolling content.
        guard scrollableHeight > scrollView.bounds.height + 50 else { return }

        let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height
        let depth = min(max(visibleBottom / scrollableHeight, 0), 1)

        guard
            let milestone = Self.milestones.last(where: { depth >= $0 }),
            milestone > reportedMilestone
        else { return }
        reportedMilestone = milestone

        guard
            let client = ImpulseSDK.client,
            client.isEnabled,
            client.configuration.autoCapture.contains(.scrolls)
        else { return }
        client.tracker.scroll(depth: milestone)
    }
}

extension UIScrollView {
    @objc fileprivate func impulse_didMoveToWindow() {
        impulse_didMoveToWindow()
        ScrollAutoCapture.handleMovedToWindow(self)
    }
}
