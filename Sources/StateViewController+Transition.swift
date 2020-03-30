#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

internal extension StateViewController {

    @discardableResult
    func beginStateTransition(to state: State, animated: Bool) -> Bool {
        // If we're not changing the state, what's the point?
        guard state != stateInternal else {
            return false
        }

        // We may not have made any changes to content view controllers, even though we have changed the state.
        // Therefore, we must be prepare to end the state transition immediately.
        defer {
            endStateTransitionIfNeeded(animated: animated)
        }

        // If we're transitioning between states, we need to abort and wait for the current state
        // transition to finish.
        guard isTransitioningBetweenStates == false else {
            pendingState = (state: state, animated: animated)
            return false
        }

        // Invoke callback method, indicating that we will change state
        willTransition(to: state, animated: animated)
        dispatchStateEvent(.willTransitionTo(nextState: state, animated: animated))

        // Note that we're transitioning from a state
        transitioningFromState = state

        // Update the current state
        stateInternal = state

        // View controllers before the state transition
        let previous = children

        // View controllers after the state transition
        let next = children(for: state)

        // View controllers that were not representing the previous state
        let adding = next.filter { previous.contains($0) == false }

        // View controllers that were representing the previous state, but no longer are
        let removing = previous.filter { next.contains($0) == false }

        // Prepare for removing view controllers
        for viewController in removing {
            willRemoveChild(viewController, animated: animated)
        }

        // Prepare for adding view controllers
        for viewController in adding {
            addChild(viewController, animated: animated)
        }

        #if os(iOS)
        if adding.isEmpty == false || removing.isEmpty == false {
            setNeedsStatusBarAppearanceUpdate()

            if #available(iOS 11, *) {
                setNeedsUpdateOfHomeIndicatorAutoHidden()
                setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            }
        }
        #endif

        // Update the hierarchy of the view controllers that will represent the state being transitioned to.
        updateHierarchy(of: next)
        return true
    }

    /// Performs the state transition, on a per-view controller basis, and ends the state transition if needed.
    func performStateTransition(animated: Bool) {

        // Perform animations for each adding view controller
        for viewController in viewControllersBeingAdded {
            performStateTransition(for: viewController, isAppearing: true) {
                self.didAddChild(viewController, animated: animated)
                self.endStateTransitionIfNeeded(animated: animated)
            }
        }

        // Perform animations for each removing view controller
        for viewController in viewControllersBeingRemoved {
            performStateTransition(for: viewController, isAppearing: false) {
                self.removeChild(viewController, animated: animated)
                self.endStateTransitionIfNeeded(animated: animated)
            }
        }
    }

    /// Ends the state transition if a) an apperance transition is not in progress, b) if no
    /// view controllers are in a state transition.
    ///
    /// - Parameter animated: Whether the state transition was animated.
    func endStateTransitionIfNeeded(animated: Bool) {

        // We're not transitioning from a state, so what gives?
        guard let fromState = transitioningFromState else {
            return
        }

        // We're in an appearance transition. This method will be called again when this is no longer the case.
        guard isInAppearanceTransition == false else {
            return
        }

        // There are still view controllers in a state transition.
        // This method will be called again when this is no longer the case.
        guard viewControllersBeingAdded.union(viewControllersBeingRemoved).isEmpty else {
            return
        }

        // Note that we're no longer transitioning from a state
        transitioningFromState = nil

        // Notify that we're finished transitioning
        dispatchStateEvent(.didTransitionFrom(previousState: fromState, animated: animated))
        didTransition(from: fromState, animated: animated)

        // If we still need another state, let's transition to it immediately.
        if let (state, animated) = pendingState {
            pendingState = nil
            setNeedsStateTransition(to: state, animated: animated)
        }
    }

    /// Performs the state transition for a given view controller
    ///
    /// - Parameters:
    ///   - viewController: View controller to animate
    ///   - isAppearing: Whether the transition is animated
    ///   - completion: Completion handler
    func performStateTransition(
        for viewController: ViewController,
        isAppearing: Bool,
        completion: @escaping () -> Void) {

        // Transitioning corodinator to use for the animation

        viewController.stateTransitionWillBegin(isAppearing: isAppearing)

        // Set up an animation block
        let animations: () -> Void = {
            viewController.animateAlongsideStateTransition(isAppearing: isAppearing)
        }

        let duration = viewController.stateTransitionDuration(isAppearing: isAppearing)

        let delay: TimeInterval = viewController.stateTransitionDelay(isAppearing: isAppearing)

        let completion = {
            viewController.stateTransitionDidEnd(isAppearing: isAppearing)
            completion()
        }

        #if canImport(UIKit)
        // For iOS 10 and above, we use UIViewPropertyAnimator
        if #available(iOS 10, tvOS 10, *) {
            let animator = UIViewPropertyAnimator(
                duration: duration,
                dampingRatio: 1,
                animations: animations
            )

            animator.addCompletion { _ in
                completion()
            }

            animator.startAnimation(afterDelay: delay)
            // For iOS 9 and below, we use a spring animations
        } else {

            UIView.animate(
                withDuration: duration,
                delay: delay,
                usingSpringWithDamping: 1,
                initialSpringVelocity: 0,
                options: [],
                animations: animations) { _ in
                    completion()
            }
        }
        #elseif canImport(AppKit)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            animations()
        }, completionHandler: completion)

        #endif
    }
}
