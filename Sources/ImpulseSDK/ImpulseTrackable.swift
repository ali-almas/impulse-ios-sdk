//
//  ImpulseTrackable.swift
//  ImpulseSDK
//

import UIKit

/// Adopt on a view controller to give its auto-captured screen a stable,
/// human-readable name (instead of the class name). With
/// `autoCaptureOnlyTrackableScreens` enabled, only conforming controllers
/// are auto-captured.
public protocol ImpulseTrackable where Self: UIViewController {
    var screenName: String { get }
}
