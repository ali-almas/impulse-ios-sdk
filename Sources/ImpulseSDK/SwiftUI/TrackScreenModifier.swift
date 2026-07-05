//
//  TrackScreenModifier.swift
//  ImpulseSDK
//

import SwiftUI

/// Tracks a SwiftUI view as a screen: `screen_view` on appear, and
/// `screen_exit` with dwell time on disappear.
struct TrackScreenModifier: ViewModifier {
    let screenName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                MainActor.assumeIsolated {
                    Impulse.screen(screenName)
                }
            }
            .onDisappear {
                MainActor.assumeIsolated {
                    Impulse.screenClosed(screenName)
                }
            }
    }
}

public extension View {
    /// Marks this view as a screen in the user journey. Dwell time is
    /// measured from appear to disappear.
    func trackScreen(_ screenName: String) -> some View {
        modifier(TrackScreenModifier(screenName: screenName))
    }
}
