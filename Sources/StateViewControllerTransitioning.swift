#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// View controllers can conform to this protocol to provide their desired
/// state transitioning behaviour when contained in a `StateViewController`.
@objc
public protocol StateViewControllerTransitioning: AnyObject {

    /// Returns the animation duration for a state transition of this view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    /// - Returns: A transition duration.
    @objc
    func stateTransitionDuration(isAppearing: Bool) -> TimeInterval

    /// Notifies that a state transition will begin for this view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    @objc
    func stateTransitionWillBegin(isAppearing: Bool)

    /// Notifies that a state transition did end for this view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    @objc
    func stateTransitionDidEnd(isAppearing: Bool)

    /// Animations performed alongside the state transition of this view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    @objc
    func animateAlongsideStateTransition(isAppearing: Bool)

    /// Returns the animation delay for a state transition of the provided view controller.
    ///
    /// - Parameter isAppearing: Whether this view controller is appearing.
    /// - Returns: A transition duration.
    @objc
    func stateTransitionDelay(isAppearing: Bool) -> TimeInterval
}

#if canImport(AppKit)
extension NSViewController: StateViewControllerTransitioning {

    open func stateTransitionDuration(isAppearing: Bool) -> TimeInterval {
        3.5
    }

    open func stateTransitionWillBegin(isAppearing: Bool) {
        view.alphaValue = isAppearing ? 0 : 1
    }

    open func stateTransitionDidEnd(isAppearing: Bool) {
        view.alphaValue = 1
    }

    open func animateAlongsideStateTransition(isAppearing: Bool) {
        view.animator().alphaValue = isAppearing ? 1 : 0
    }

    open func stateTransitionDelay(isAppearing: Bool) -> TimeInterval {
        0
    }


}
#endif
