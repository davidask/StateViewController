#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// View controllers can conform to this protocol to provide their desired
/// state transitioning behaviour when contained in a `StateViewController`.
public protocol StateViewControllerTransitioning: AnyObject {

    /// Returns the animation duration for a state transition of this view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    /// - Returns: A transition duration.
    func stateTransitionDuration(isAppearing: Bool) -> TimeInterval

    /// Notifies that a state transition will begin for this view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    func stateTransitionWillBegin(isAppearing: Bool)

    /// Notifies that a state transition did end for this view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    func stateTransitionDidEnd(isAppearing: Bool)

    /// Animations performed alongside the state transition of this view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    func animateAlongsideStateTransition(isAppearing: Bool)

    /// Returns the animation delay for a state transition of the provided view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    /// - Returns: A transition duration
    func stateTransitionDelay(isAppearing: Bool) -> TimeInterval
}
