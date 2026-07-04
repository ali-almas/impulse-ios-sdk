//
//  TrackScreenModifier.swift
//  ImpulseSDK
//
//  Created by Ali Almasli on 05.07.26.
//

import SwiftUI

struct TrackScreenModifier: ViewModifier {
    let screenName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                print("OPENED: ", screenName)
            }
            .onDisappear {
                print("CLOSED: ", screenName)
            }
    }
}

public extension View {
    func trackScreen(_ screenName: String) -> some View {
        modifier(TrackScreenModifier(screenName: screenName))
    }
}
