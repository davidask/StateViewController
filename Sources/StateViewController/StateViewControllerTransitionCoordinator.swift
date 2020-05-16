import UIKit

/// This protocol is used by `StateViewController` to animate state transitions.
/// If you want to customize state transition animations on a per-viewcontroller basis you can make your content
/// view controller classes conform to `StateViewControllerTransitioning`, or override
/// `stateTransitionCoordinator(for:)` on each `StateViewController`
public protocol StateViewControllerTransitionCoordinator {

    /// Returns the animation duration for a state transition of the provided view controller.
    ///
    /// - Parameters:
    ///   - viewController: `StateViewController` content view controller.
    ///   - isAppearing: Whether the content view controller is appearing.
    /// - Returns: An animation duration.
    func stateTransitionDuration(for viewController: UIViewController, isAppearing: Bool) -> TimeInterval

    /// Notifies that a state transition will begin for the provided view controller.
    ///
    /// - Parameters:
    ///   - viewController: `StateViewController` content view controller.
    ///   - isAppearing: Whether the content view controller is appearing.
    func stateTransitionWillBegin(viewController: UIViewController, isAppearing: Bool)

    /// Notifies that a state transition did end for the provided view controller.
    ///
    ///   - viewController: `StateViewController` content view controller.
    ///   - isAppearing: Whether the content view controller is appearing.
    func stateTransitionDidEnd(viewController: UIViewController, isAppearing: Bool)

    /// Animations performed alongside the state transition of the provided view controller.
    ///
    /// - Parameters:
    ///   - viewController: `StateViewController` content view controller.
    ///   - isAppearing: Whether the content view controller is appearing.
    func animateAlongsideStateTransition(of viewController: UIViewController, isAppearing: Bool)

    /// Returns the animation delay for a state transition of the provided view controller.
    ///
    /// - Parameters:
    ///   - viewController: `StateViewController` content view controller.
    ///   - isAppearing: Whether the content view controller is appearing.
    /// - Returns: An animation delay.
    func stateTransitionDelay(for viewController: UIViewController, isAppearing: Bool) -> TimeInterval
}
