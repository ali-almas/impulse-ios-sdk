//
//  ScrollAutoCapture.swift
//  ImpulseSDK
//

import UIKit
import ObjectiveC.runtime

/// Records the deepest scroll position reached on a scroll view. A single
/// `scroll` step with the max depth is emitted when the scroll view leaves
/// the screen — scrolling up and down in between produces nothing extra.
/// Installed only when `AutoCaptureOptions.scrolls` is enabled.
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
            if let observer = objc_getAssociatedObject(scrollView, &observerKey) as? ScrollDepthObserver {
                observer.finish()
                objc_setAssociatedObject(
                    scrollView, &observerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
            return
        }
        guard
            let client = Impulse.client,
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

/// Watches one scroll view's content offset and remembers the deepest
/// point the user reached; reports it once via `finish()`.
@MainActor
private final class ScrollDepthObserver {
    private var observation: NSKeyValueObservation?
    /// Depth visible before any user scrolling; reporting is skipped when
    /// the user never went meaningfully past it.
    private var baselineDepth: Double?
    private var maxDepth: Double = 0
    /// Screen the deepest scroll happened on, captured while scrolling
    /// because the current screen may have changed by report time.
    private var screenName: String?

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

        if baselineDepth == nil {
            baselineDepth = depth
        }
        if depth > maxDepth {
            maxDepth = depth
            screenName = Impulse.client?.tracker.currentScreenName
        }
    }

    /// Emits one scroll step with the deepest position reached.
    func finish() {
        observation?.invalidate()
        observation = nil

        guard let baselineDepth, maxDepth > baselineDepth + 0.05 else { return }
        guard
            let client = Impulse.client,
            client.isEnabled,
            client.configuration.autoCapture.contains(.scrolls)
        else { return }
        client.tracker.scroll(
            depth: (maxDepth * 100).rounded() / 100,
            screenName: screenName
        )
    }
}

extension UIScrollView {
    @objc fileprivate func impulse_didMoveToWindow() {
        impulse_didMoveToWindow()
        ScrollAutoCapture.handleMovedToWindow(self)
    }
}
