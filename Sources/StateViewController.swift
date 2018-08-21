public extension Notification.Name {
    /// Notification name that fires when a state view controller updates its view hierarchy
    static let stateViewControllerDidChangeViewHierarchy = Notification.Name(
        "stateViewControllerDidChangeViewHierarchy"
    )
}

/// The default `StateViewControllerTransitionCoordinator` used, if `stateTransitionCoordinator(for:)` returns nil
/// or if a view content view controller of `StateViewController` does not conform to
/// `StateViewControllerTransitioning`.
public var defaultStateTransitionCoordinator: StateViewControllerTransitionCoordinator?

/// A container view controller that manages the appearance of one or more child view controller for any given state.
///
/// ## Overview
/// This class is designed to make stateful view controller programming easier. Typically in iOS development,
/// views representing multiple states are managed in one single view controller, leading to large view controller
/// classes that quickly become hard to work with and overlook at a glance. For instance, a view controller may
/// display an activity indicator while a network call is performed, leaving the view controller to have to directly
/// manipulate view hierarhy for each state. Furthermore, the state of a view controller tends to be represented by
/// conditions that are hard to synchronize, easily becoming a source of bugs and unexpected behavior.
/// With `StateViewController` each state can be represented by one or more view controllers.
/// This allows you to composite view controllers in self-contained classes resulting in smaller view
/// controllers and better ability modularize your view controller code, with clear separation between states.
///
/// ## Subclassing notes
///
/// You must subclass `StateViewController` and define a state for the view controller you are creating.
/// ```
/// enum MyViewControllerState: Equatable {
///     case loading
///     case ready
/// }
/// ```
/// **Note:** Your state must conform to `Equatable` in order for `StateViewController` to distinguish between states.
///
/// Override `loadAppearanceState()` to determine which state is being represented each time this view controller
/// is appearing on screen. In this method is appropriate to query your model layer to determine whether data needed
/// for a certain state is available or not.
///
/// ```
/// override func loadAppearanceState() -> MyViewControllerState {
///     if model.isDataAvailable {
///         return .ready
///     } else {
///         return .loading
///     }
/// }
/// ```
///
/// To determine which content view controllers represent a particular state, you must override
/// `contentViewControllers(for:)`.
///
/// ```
/// override func contentViewControllers(for state: MyViewControllerState) -> [UIViewController] {
///     switch state {
///     case .loading:
///         return [ActivityIndicatorViewController()]
///     case .empty:
///         return [myContentViewController]
///     }
/// }
/// ```
///
/// Callback methods are overridable, notifying you when a state transition is being performed, and what child
/// view controllers are being presented as a result of a state transition.
///
/// Using `willTransition(to:animated:)` you should prepare view controller representing the state being transition to
/// with the appropriate data.
///
/// ```
/// override func willTransition(to state: MyViewControllerState, animated: Bool) {
///     switch state {
///     case .ready:
///         myContentViewController.content = myLoadedContent
///     case .loading:
///         break
///     }
/// }
/// ```
/// Overriding `didTransition(to:animated:)` is an appropriate place to invoke methods that eventually results in
/// a state transition being requested using `setNeedsTransition(to:animated:)`, as it ensures that any previous state
/// transitions has been fully completed.
///
/// ```
/// override func didTransition(from previousState: MyViewControllerState?, animated: Bool) {
///     switch state {
///     case .ready:
///         break
///     case .loading:
///         model.loadData { result in
///             self.myLoadedContent = result
///             self.setNeedsTransition(to: .ready, animated: true)
///         }
///     }
/// }
/// ```
///
/// You may also override `loadContentViewControllerContainerView()` to provide a custom container view for your
/// content view controllers, allowing you to manipulate the view hierarchy above and below the content view
/// controller container view.
///
/// ## Animating state transitions
/// By default, no animations are performed between states. To enable animations, you have three options:
///
/// - Set `defaultStateTransitioningCoordinator`
/// - Override `stateTransitionCoordinator(for:)` in your `StateViewController` subclasses
/// - Conform view controllers contained in `StateViewController` to `StateViewControllerTransitioning`.
///
///
open class StateViewController<State: Equatable>: UIViewController {

    /// Current state storage
    fileprivate var stateInternal: State?

    /// A state currently being transitioned from.
    /// - Note: This property is an optional of an optional, as the previous state may be `nil`.
    fileprivate var transitioningFromState: State??

    /// Indicates whether the state view controller is in an appearance transition, between `viewWillAppear` and
    /// `viewDidAppear`, **or** between `viewWillDisappear` and `viewDidDisappear`.
    fileprivate var isInAppearanceTransition = false

    /// Indicates whether the state view controller is applying an appearance state, as part of its appearance cycle
    fileprivate var isApplyingAppearanceState = false

    /// Stores the next needed state to be transitioned to immediately after a current state transition is finished
    fileprivate var pendingState: (state: State, animated: Bool)?

    /// Set of child view controllers being added as part of a state transition
    fileprivate var viewControllersBeingAdded: Set<UIViewController> = []

    /// Set of child view controllers being removed as part of a state transition
    fileprivate var viewControllersBeingRemoved: Set<UIViewController> = []

    /// :nodoc:
    public final override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false // We completely manage forwarding of appearance methods ourselves.
    }

    // MARK: - View lifecycle

    /// :nodoc:
    open override func viewDidLoad() {
        super.viewDidLoad()

        contentViewControllerContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentViewControllerContainerView.frame = view.bounds
        view.addSubview(contentViewControllerContainerView)
    }

    /// :nodoc:
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Note that we're in an appearance transition
        isApplyingAppearanceState = false
        isInAppearanceTransition = false

        // Load the appearance state once
        let appearanceState = loadAppearanceState()

        // If the required appearance state does not match the current state, begin applying appearance state.
        if stateInternal != appearanceState {
            // Note that we're applying the appearance state for this appearance cycle.
            if isMovingToParentViewController {
                setNeedsStateTransition(to: appearanceState, animated: animated)
            } else {
                isApplyingAppearanceState = beginStateTransition(to: appearanceState, animated: animated)
            }
        }

        // Prematurely remove view controllers that are being removed.
        // They do not need to be visible what so ever.
        // As we're not yet setting the `isInAppearanceTransition` to `true`, the appearance methods
        // for each child view controller below will be forwarded correctly.
        for child in viewControllersBeingRemoved {
            removeContentViewController(child, animated: false)
        }

        // Note that we're not in an appearance transition
        isInAppearanceTransition = true

        // Forward begin appearance transitions to child view controllers
        forwardBeginApperanceTransition(isAppearing: true, animated: animated)
    }

    /// :nodoc:
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Note that we're no longer in an appearance transition
        isInAppearanceTransition = false

        // Forward end appearance transitions to chidl view controllers
        forwardEndAppearanceTransition(didAppear: true, animated: animated)

        // If we're applying the appearance state, finish up by making sure
        // `didMove(to:)` is called on child view controllers.
        if isApplyingAppearanceState {
            for child in viewControllersBeingAdded {
                didAddContentViewController(child, animated: animated)
            }
        }

        // End state transition if needed. Child view controllers may still be in a transition,
        endStateTransitionIfNeeded(animated: animated)
    }

    /// :nodoc:
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        isInAppearanceTransition = false

        // If we're being dismissed we might as well clear the pending state.
        pendingState = nil

        /// If there are view controllers being added as part of a current state transition, we should
        // add them immediately.
        for child in viewControllersBeingAdded {
            didAddContentViewController(child, animated: animated)
        }

        // Note that we're in an appearance transition
        isInAppearanceTransition = true

        // Forward begin appearance methods
        forwardBeginApperanceTransition(isAppearing: false, animated: animated)
    }

    /// :nodoc:
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Note that we're no longer in an apperance transition
        isInAppearanceTransition = false

        // Prematurely remove all view controllers begin removed
        for child in viewControllersBeingRemoved {
            removeContentViewController(child, animated: animated)
        }

        // Forward end appearance transitions. Will only affect child view controllers not currently
        // in a state transition.
        forwardEndAppearanceTransition(didAppear: false, animated: animated)

        // End state transition if needed.
        endStateTransitionIfNeeded(animated: animated)
    }

    // MARK: - State transitioning

    /// Indicates whether the view controller currently is transitioning between states.
    public var isTransitioningBetweenStates: Bool {
        return transitioningFromState != nil
    }

    /// Indicates the current state, or invokes `loadAppearanceState()` is a current state transition has not
    /// yet began.
    public var currentState: State {
        return stateInternal ?? loadAppearanceState()
    }

    /// Indicates whether the state of this view controller has been determined.
    /// In effect, this means that if this value is `true`, you can access `currentState` inside
    // `loadAppearanceState()` without resulting in infinite recursion.
    public var hasDeterminedState: Bool {
        return stateInternal != nil
    }

    /// Loads a state that should represent this view controller immediately as this view controller
    /// is being presented on screen, and returns it.
    ///
    /// - Warning: As `currentState` may invoke use this method you cannot access `currentState` inside this
    /// method without first asserting that `hasDeterminedState` is `true`.
    ///
    /// - Returns: A state
    open func loadAppearanceState() -> State {
        fatalError("Not implemented")
    }

    /// Notifies the state view controller that a new state is needed.
    /// As soon as the state view controller is ready to change state, a state transition will begin.
    ///
    /// - Note: Multiple calls to this method will result in the last state provided being transitioned to.
    ///
    /// - Parameters:
    ///   - state: State to transition to.
    ///   - animated: Whether to animate the state transition.
    public func setNeedsStateTransition(to state: State, animated: Bool) {

        guard beginStateTransition(to: state, animated: animated) else {
            return
        }

        guard animated else {
            for viewController in viewControllersBeingAdded {
                didAddContentViewController(viewController, animated: animated)
            }

            for viewController in viewControllersBeingRemoved {
                removeContentViewController(viewController, animated: animated)
            }
            return
        }

        performStateTransition(animated: animated)
    }

    // MARK: - Content view controllers

    /// Returns an array of content view controllers representing a state.
    /// The order of the view controllers matter – first in array will be placed first in the container views
    /// view hierarchy.
    ///
    /// - Parameter state: State being represented
    /// - Returns: An array of view controllers
    open func contentViewControllers(for state: State) -> [UIViewController] {
        return []
    }

    /// Internal storage of `contentViewControllerContainerView`
    private var _contentViewControllerContainerView: UIView?

    /// Container view placed directly in the `StateViewController`s view.
    /// Content view controllers are placed inside this view, edge to edge.
    /// - Important: You should not directly manipulate the view hierarchy of this view
    public var contentViewControllerContainerView: UIView {
        guard let existing = _contentViewControllerContainerView else {
            let new = loadContentViewControllerContainerView()
            new.preservesSuperviewLayoutMargins = true
            _contentViewControllerContainerView = new
            return new
        }

        return existing
    }

    /// Creates the `contentViewControllerContainerView` used as a container view for content view controllers.
    //
    /// - Note: This method is only called once.
    ///
    /// - Returns: A `UIView` if not overridden.
    open func loadContentViewControllerContainerView() -> UIView {
        return UIView()
    }

    // MARK: - Callbacks

    /// Notifies the view controller that a state transition is to be performed.
    ///
    /// Use this method to prepare view controller representing the given state for display.
    ///
    /// - Parameters:
    ///   - nextState: State that will be transitioned to.
    ///   - animated: Indicates whether the outstanding transition will be animated.
    open func willTransition(to nextState: State, animated: Bool) {
        return
    }

    /// Notifies the view controller that it has finished transitioning to a new state.
    ///
    /// As this method guarantees that a state transition has fully completed, this function is a good place
    /// to call `setNeedsTransition(to:animated:)`, or methods that eventually (asynchronously or synchronously) calls
    /// that method.
    ///
    /// - Parameters:
    ///   - state: State
    ///   - animated: If true, the state transition was animated
    open func didTransition(from previousState: State?, animated: Bool) {
        return
    }

    /// Notifies the view controller that a content view controller will appear.
    ///
    /// - Parameters:
    ///   - viewController: View controller appearing.
    ///   - animated: Indicates whether the appearance is animated.
    open func contentViewControllerWillAppear(_ viewController: UIViewController, animated: Bool) {
        return
    }

    /// Notifies the view controller that a content view controller did appear.
    ///
    /// This method is well suited as a function to add targets and listeners that should only be present when
    /// the provided content view controller is on screen.
    ///
    /// - Parameters:
    ///   - viewController: View controller appeared.
    ///   - animated: Indicates whether the apperance was animated.
    open func contentViewControllerDidAppear(_ viewController: UIViewController, animated: Bool) {
        return
    }

    /// Notifies the view controller that a content view controller will disappear.
    /// This method is well suited as a fucntion to remove targets and listerners that should only be present
    /// when the content view controller is on screen.
    ///
    /// - Parameters:
    ///   - viewController: View controller disappearing.
    ///   - animated: Indicates whether the disappearance is animated.
    open func contentViewControllerWillDisappear(_ viewController: UIViewController, animated: Bool) {
        return
    }

    /// Notifies the view controller that a content view controller did disappear.
    ///
    /// - Parameters:
    ///   - viewController: Content view controller disappearad.
    ///   - animated: Indicates whether the disappearance was animated.
    open func contentViewControllerDidDisappear(_ viewController: UIViewController, animated: Bool) {
        return
    }

    // MARK: - Animation

    /// Returns an optional `StateViewControllerTransitionCoordinator`, used to animate transitions between
    /// states.
    ///
    /// If the provided view controller conforms to `StateViewControllerTransitioning`, and this method returns
    /// non-nil, the returned `StateViewControllerTransitionCoordinator` is used to animate the state transition
    /// of the provided view controller.
    ///
    /// - Parameter contentViewController: Content view controller.
    /// - Returns: A `StateViewControllerTransitionCoordinator`, or `nil`.
    open func stateTransitionCoordinator(
        for contentViewController: UIViewController) -> StateViewControllerTransitionCoordinator? {
        return nil
    }
}

fileprivate extension StateViewController {

    /// Forwards begin appearance methods to child view controllers not currently in a state transition,
    /// and invokes callback methods provided by this class.
    ///
    /// - Parameters:
    ///   - isAppearing: Whether this view controller is appearing
    ///   - animated: Whether the appearance or disappearance of this view controller is animated
    func forwardBeginApperanceTransition(isAppearing: Bool, animated: Bool) {

        // Don't include view controlellers in a state transition.
        // Appearance method forwarding will be performed at a later stage
        let excluded = viewControllersBeingAdded.union(viewControllersBeingRemoved)

        for viewController in childViewControllers where excluded.contains(viewController) == false {

            // Invoke the appropriate callback method
            if isAppearing {
                contentViewControllerWillAppear(viewController, animated: animated)
            } else {
                contentViewControllerWillDisappear(viewController, animated: animated)
            }

            viewController.beginAppearanceTransition(isAppearing, animated: animated)
        }
    }

    func forwardEndAppearanceTransition(didAppear: Bool, animated: Bool) {

        // Don't include view controlellers in a state transition.
        // Appearance method forwarding will be performed at a later stage.
        let excluded = viewControllersBeingAdded.union(viewControllersBeingRemoved)

        for viewController in childViewControllers where excluded.contains(viewController) == false {
            viewController.endAppearanceTransition()

            // Invoke the appropriate callback method
            if didAppear {
                contentViewControllerDidAppear(viewController, animated: animated)
            } else {
                contentViewControllerDidDisappear(viewController, animated: animated)
            }
        }
    }
}

fileprivate extension StateViewController {

    @discardableResult
    func beginStateTransition(to state: State, animated: Bool) -> Bool {

        // If we're not changing the state, what's the point?
        guard state != stateInternal else {
            return false
        }

        // If we're transitioning between states, we need to abort and wait for the current state
        // transition to finish.
        guard isTransitioningBetweenStates == false else {
            pendingState = (state: state, animated: animated)
            return false
        }

        // Invoke callback method, indicating that we will change state
        willTransition(to: state, animated: animated)

        // We may not have made any changes to content view controllers, even though we have changed the state.
        // Therefore, we must be prepare to end the state transition immediately.
        defer {
            endStateTransitionIfNeeded(animated: animated)
        }

        // Note that we're transitioning from a state
        transitioningFromState = state

        // Update the current state
        stateInternal = state

        // View controllers before the state transition
        let previous = childViewControllers

        // View controllers after the state transition
        let next = contentViewControllers(for: state)

        // View controllers that were not representing the previous state
        let adding = next.filter { previous.contains($0) == false }

        // View controllers that were representing the previous state, but no longer are
        let removing = previous.filter { next.contains($0) == false }

        // Prepare for removing view controllers
        for viewController in removing {
            willRemoveContentViewController(viewController, animated: animated)
        }

        // Prepare for adding view controllers
        for viewController in adding {
            addContentViewController(viewController, animated: animated)
        }

        // Update the hierarchy of the view controllers that will represent the state being transitioned to.
        updateHierarchy(of: next)
        return true
    }

    /// Performs the state transition, on a per-view controller basis, and ends the state transition if needed.
    func performStateTransition(animated: Bool) {

        // Perform animations for each adding view controller
        for viewController in viewControllersBeingAdded {
            performStateTransition(for: viewController, isAppearing: true) {
                self.didAddContentViewController(viewController, animated: animated)
                self.endStateTransitionIfNeeded(animated: animated)
            }
        }

        // Perform animations for each removing view controller
        for viewController in viewControllersBeingRemoved {
            performStateTransition(for: viewController, isAppearing: false) {
                self.removeContentViewController(viewController, animated: animated)
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
        didTransition(from: fromState, animated: animated)

        // If we still need another state, let's transition to it immediately.
        if let (state, animated) = pendingState {
            pendingState = nil
            setNeedsStateTransition(to: state, animated: animated)
        }
    }
}

fileprivate extension StateViewController {

    /// Performs the state transition for a given view controller
    ///
    /// - Parameters:
    ///   - viewController: View controller to animate
    ///   - isAppearing: Whether the transition is animated
    ///   - completion: Completion handler
    func performStateTransition(
        for viewController: UIViewController,
        isAppearing: Bool,
        completion: @escaping () -> Void) {

        // Transitioning corodinator to use for the animation
        let coordinator = stateTransitionCoordinator(for: viewController)

        weak var cast = viewController as? StateViewControllerTransitioning

        if let coordinator = coordinator {
            coordinator.stateTransitionWillBegin(viewController: viewController, isAppearing: isAppearing)
        } else if let cast = cast {
            cast.stateTransitionWillBegin(isAppearing: isAppearing)
        } else {
            defaultStateTransitionCoordinator?.stateTransitionWillBegin(
                viewController: viewController,
                isAppearing: isAppearing
            )
        }

        // Set up an animation block
        let animations = {
            // Which performs the animations
            if let coordinator = coordinator {
                coordinator.animateAlongsideStateTransition(of: viewController, isAppearing: isAppearing)
            } else if let cast = cast {
                cast.animateAlongsideStateTransition(isAppearing: isAppearing)
            } else {
                defaultStateTransitionCoordinator?.animateAlongsideStateTransition(
                    of: viewController,
                    isAppearing: isAppearing
                )
            }
        }

        let duration: TimeInterval

        if let coordinator = coordinator {
            duration = coordinator.stateTransitionDuration(for: viewController, isAppearing: isAppearing)
        } else {
            duration = cast?.stateTransitionDuration(
                isAppearing: isAppearing
            ) ?? defaultStateTransitionCoordinator?.stateTransitionDuration(
                for: viewController,
                isAppearing: isAppearing
            ) ?? 0
        }

        let delay: TimeInterval

        if let coordinator = coordinator {
            delay = coordinator.stateTransitionDelay(for: viewController, isAppearing: isAppearing)
        } else {
            delay = cast?.stateTransitionDelay(
                isAppearing: isAppearing
            ) ?? defaultStateTransitionCoordinator?.stateTransitionDelay(
                for: viewController,
                isAppearing: isAppearing
            ) ?? 0
        }

        // For iOS 10 and above, we use UIViewPropertyAnimator
        if #available(iOS 10, *) {
            let animator = UIViewPropertyAnimator(
                duration: duration,
                dampingRatio: 1,
                animations: animations
            )

            animator.addCompletion { _ in
                if let coordinator = coordinator {
                    coordinator.stateTransitionDidEnd(viewController: viewController, isAppearing: isAppearing)
                } else if let cast = cast {
                    cast.stateTransitionDidEnd(isAppearing: isAppearing)
                } else {
                    defaultStateTransitionCoordinator?.stateTransitionDidEnd(
                        viewController: viewController,
                        isAppearing: isAppearing
                    )
                }

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
    }
}

fileprivate extension StateViewController {

    func updateHierarchy(of viewControllers: [UIViewController]) {

        for (index, viewController) in viewControllers.enumerated() {
            viewController.view.translatesAutoresizingMaskIntoConstraints = true
            viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            viewController.view.bounds.size = contentViewControllerContainerView.bounds.size
            viewController.view.center = contentViewControllerContainerView.center

            contentViewControllerContainerView.insertSubview(viewController.view, at: index)
        }

        // Tell everyone we're updating the view hierarchy
        NotificationCenter.default.post(name: .stateViewControllerDidChangeViewHierarchy, object: self)

        // Make sure that contentInsets for scroll views are updated as we go, in case we're targeting
        // iOS 10 or below.
        triggerAutomaticAdjustmentOfScrollViewInsetsIfNeeded()
    }

    /// Prompts the encloding `UINavigationController` and `UITabBarController` to layout their subviews,
    /// triggering them to adjust the scrollview insets
    func triggerAutomaticAdjustmentOfScrollViewInsetsIfNeeded() {

        // Don't do anything if we're on iOS 11 or above
        if #available(iOS 11, *) {
            return
        }

        // Also don't do anything if this view is set to not adjust scroll view insets
        guard automaticallyAdjustsScrollViewInsets else {
            return
        }

        navigationController?.view.setNeedsLayout()
        tabBarController?.view.setNeedsLayout()
    }

}

fileprivate extension StateViewController {

    /// Adds a content view controller to the state view controller
    ///
    /// - Parameters:
    ///   - viewController: View controller to add
    ///   - animated: Whether part of an animated transition
    func addContentViewController(_ viewController: UIViewController, animated: Bool) {

        guard viewControllersBeingAdded.contains(viewController) == false else {
            return
        }

        addChildViewController(viewController)

        // If we're not in an appearance transition, forward appearance methods.
        // If we are, appearance methods will be forwarded at a later time
        if isInAppearanceTransition == false {
            contentViewControllerWillAppear(viewController, animated: animated)
            viewController.beginAppearanceTransition(true, animated: animated)
        }

        viewControllersBeingAdded.insert(viewController)
    }

    func didAddContentViewController(_ viewController: UIViewController, animated: Bool) {

        guard viewControllersBeingAdded.contains(viewController) else {
            return
        }

        // If we're not in an appearance transition, forward appearance methods.
        // If we are, appearance methods will be forwarded at a later time
        if isInAppearanceTransition == false {
            viewController.endAppearanceTransition()
            contentViewControllerDidAppear(viewController, animated: animated)
        }

        viewController.didMove(toParentViewController: self)
        viewControllersBeingAdded.remove(viewController)
    }

    func willRemoveContentViewController(_ viewController: UIViewController, animated: Bool) {

        guard viewControllersBeingRemoved.contains(viewController) == false else {
            return
        }

        viewController.willMove(toParentViewController: nil)

        // If we're not in an appearance transition, forward appearance methods.
        // If we are, appearance methods will be forwarded at a later time
        if isInAppearanceTransition == false {
            contentViewControllerWillDisappear(viewController, animated: animated)
            viewController.beginAppearanceTransition(false, animated: animated)
        }

        viewControllersBeingRemoved.insert(viewController)
    }

    func removeContentViewController(_ viewController: UIViewController, animated: Bool) {

        guard viewControllersBeingRemoved.contains(viewController) else {
            return
        }

        viewController.view.removeFromSuperview()
        NotificationCenter.default.post(name: .stateViewControllerDidChangeViewHierarchy, object: self)

        // If we're not in an appearance transition, forward appearance methods.
        // If we are, appearance methods will be forwarded at a later time
        if isInAppearanceTransition == false {
            viewController.endAppearanceTransition()
            contentViewControllerDidDisappear(viewController, animated: animated)
        }

        viewController.removeFromParentViewController()
        viewControllersBeingRemoved.remove(viewController)
    }
}
