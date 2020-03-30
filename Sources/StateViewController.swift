#if canImport(UIKit)
import UIKit
public typealias ViewController = UIViewController
#elseif canImport(AppKit)
import AppKit
public typealias ViewController = NSViewController
#endif

public protocol StateChildViewController {}

public extension Notification.Name {
    /// Notification name that fires when a state view controller updates its view hierarchy
    static let stateViewControllerDidChangeViewHierarchy = Notification.Name(
        "stateViewControllerDidChangeViewHierarchy"
    )
}

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
/// `children(for:)`.
///
/// ```
/// override func children(for state: MyViewControllerState) -> [ViewController] {
///     switch state {
///     case .loading:
///         return [ProgressIndicatorViewController()]
///     case .empty:
///         return [myChild]
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
///         myChild.content = myLoadedContent
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
/// You may also override `loadChildContainerView()` to provide a custom container view for your
/// content view controllers, allowing you to manipulate the view hierarchy above and below the content view
/// controller container view.
///
/// ## Animating state transitions
/// By default, no animations are performed between states. To enable animations, you have three options:
///
/// - Set `defaultStateTransitioningCoordinator`
/// - Override `stateTransitionCoordinator(for:)` in your `StateViewController` subclasses
/// - Conform view controllers contained in `StateViewController` to `StateViewControllerTransitioning`.
open class StateViewController<State: Equatable>: ViewController {

    /// Current state storage
    internal var stateInternal: State?

    /// A state currently being transitioned from.
    /// - Note: This property is an optional of an optional, as the previous state may be `nil`.
    internal var transitioningFromState: State??

    /// Indicates whether the state view controller is in an appearance transition, between `viewWillAppear` and
    /// `viewDidAppear`, **or** between `viewWillDisappear` and `viewDidDisappear`.
    internal var isInAppearanceTransition = false

    /// Indicates whether the state view controller is applying an appearance state, as part of its appearance cycle
    internal var isApplyingAppearanceState = false

    /// Stores the next needed state to be transitioned to immediately after a current state transition is finished
    internal var pendingState: (state: State, animated: Bool)?

    /// Set of child view controllers being added as part of a state transition
    internal var viewControllersBeingAdded: Set<ViewController> = []

    /// Set of child view controllers being removed as part of a state transition
    internal var viewControllersBeingRemoved: Set<ViewController> = []

    #if canImport(UIKit)
    /// :nodoc:
    public final override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false // We completely manage forwarding of appearance methods ourselves.
    }
    #endif

    internal var observers: [StateViewControllerObserver<State>] = []

    // MARK: - View lifecycle

    /// :nodoc:
    open override func viewDidLoad() {
        super.viewDidLoad()

        #if canImport(UIKit)
        childContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #elseif canImport(AppKit)
        childContainerView.autoresizingMask = [.width, .height]
        #endif

        childContainerView.frame = view.bounds
        view.addSubview(childContainerView)
    }

    #if canImport(UIKIt)
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        _viewWillAppear(animated)
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _viewDidAppear(animated)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        _viewWillDisappear(animated)
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        _viewDidDisappear(animated)
    }
    #elseif canImport(AppKit)
    open override func viewWillAppear() {
        super.viewWillAppear()
        _viewWillAppear(false)
    }

    open override func viewDidAppear() {
        super.viewDidAppear()
        _viewDidAppear(false)
    }

    open override func viewWillDisappear() {
        super.viewWillDisappear()
        _viewWillDisappear(false)
    }

    open override func viewDidDisappear() {
        super.viewDidDisappear()
        _viewDidDisappear(false)
    }
    #endif

    /// :nodoc:
    private func _viewWillAppear(_ animated: Bool) {

        // When `viewWillAppear(animated:)` is called we do not yet connsider ourselves in an appearance transition
        // internally because first we have to assert whether we are changing to an appearannce state.
        isApplyingAppearanceState = false
        isInAppearanceTransition = false

        // Load the appearance state once
        let appearanceState = loadAppearanceState()

        // If the required appearance state does not match the current state, begin applying appearance state.
        if stateInternal != appearanceState {
            #if canImport(UIKIt)
            // Note that we're applying the appearance state for this appearance cycle.
            if isMovingToParent {
                setNeedsStateTransition(to: appearanceState, animated: animated)
            } else {
                isApplyingAppearanceState = beginStateTransition(to: appearanceState, animated: animated)
            }
            #else
                isApplyingAppearanceState = beginStateTransition(to: appearanceState, animated: animated)
            #endif
        }

        // Prematurely remove view controllers that are being removed.
        // As we're not yet setting the `isInAppearanceTransition` to `true`, the appearance methods
        // for each child view controller below will be forwarded correctly.
        for child in viewControllersBeingRemoved {
            removeChild(child, animated: false)
        }

        // Note that we're in an appearance transition
        isInAppearanceTransition = true

        // Forward begin appearance transitions to child view controllers.
        forwardBeginApperanceTransition(isAppearing: true, animated: animated)
    }

    /// :nodoc:
    private func _viewDidAppear(_ animated: Bool) {

        // Note that we're no longer in an appearance transition
        isInAppearanceTransition = false

        // Forward end appearance transitions to chidl view controllers
        forwardEndAppearanceTransition(didAppear: true, animated: animated)

        // If we're applying the appearance state, finish up by making sure
        // `didMove(to:)` is called on child view controllers.
        if isApplyingAppearanceState {
            for child in viewControllersBeingAdded {
                didAddChild(child, animated: animated)
            }
        }

        // End state transition if needed. Child view controllers may still be in a transition.
        endStateTransitionIfNeeded(animated: animated)
    }

    /// :nodoc:
    private func _viewWillDisappear(_ animated: Bool) {

        isInAppearanceTransition = false

        // If we're being dismissed we might as well clear the pending state.
        pendingState = nil

        /// If there are view controllers being added as part of a current state transition, we should
        // add them immediately.
        for child in viewControllersBeingAdded {
            didAddChild(child, animated: animated)
        }

        // Note that we're in an appearance transition
        isInAppearanceTransition = true

        // Forward begin appearance methods
        forwardBeginApperanceTransition(isAppearing: false, animated: animated)
    }

    /// :nodoc:
    private func _viewDidDisappear(_ animated: Bool) {

        // Note that we're no longer in an apperance transition
        isInAppearanceTransition = false

        // Prematurely remove all view controllers begin removed
        for child in viewControllersBeingRemoved {
            removeChild(child, animated: animated)
        }

        // Forward end appearance transitions. Will only affect child view controllers not currently
        // in a state transition.
        forwardEndAppearanceTransition(didAppear: false, animated: animated)

        // End state transition if needed.
        endStateTransitionIfNeeded(animated: animated)
    }

    // MARK: - Container view controller forwarding

    #if os(iOS)
    open override var childForStatusBarStyle: UIViewController? {
        children.last
    }

    open override var childForStatusBarHidden: UIViewController? {
        children.last
    }

    @available(iOS 11, *)
    open override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        children.last
    }

    @available(iOS 11, *)
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        children.last
    }
    #endif

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
    // swiftlint:disable unavailable_function
    open func loadAppearanceState() -> State {
        fatalError(
            "\(String(describing: self)) does not implement loadAppearanceState(), which is required. " +
            "A StateViewController must immediately be able to resolve its state before entering an " +
            "appearance transition."
        )
    }
    // swiftlint:enable unavailable_function

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
                didAddChild(viewController, animated: animated)
            }

            for viewController in viewControllersBeingRemoved {
                removeChild(viewController, animated: animated)
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
    open func children(for state: State) -> [ViewController] {
        return []
    }

    /// Internal storage of `childContainerView`
    #if canImport(UIKit)
    private var _childContainerView: UIView?
    #elseif canImport(AppKit)
    private var _childContainerView: NSView?
    #endif


    /// Container view placed directly in the `StateViewController`s view.
    /// Content view controllers are placed inside this view, edge to edge.
    /// - Important: You should not directly manipulate the view hierarchy of this view
    #if canImport(UIKit)
    public var childContainerView: UView {
        guard let existing = _childContainerView else {
            let new = loadChildContainerView()

            #if canImport(UIKit)
            new.preservesSuperviewLayoutMargins = true
            #endif

            _childContainerView = new
            return new
        }

        return existing
    }
    #elseif canImport(AppKit)
    public var childContainerView: NSView {
        guard let existing = _childContainerView else {
            let new = loadChildContainerView()

            _childContainerView = new
            return new
        }

        return existing
    }
    #endif

    /// Creates the `childContainerView` used as a container view for content view controllers.
    //
    /// - Note: This method is only called once.
    ///
    /// - Returns: A `View` if not overridden.
    #if canImport(UIKit)
    open func loadChildContainerView() -> UIView {
        return UIView()
    }
    #elseif canImport(AppKit)
    open func loadChildContainerView() -> NSView {
        return NSView()
    }
    #endif

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
    open func childWillAppear(_ child: ViewController, animated: Bool) {
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
    open func childDidAppear(_ child: ViewController, animated: Bool) {
        return
    }

    /// Notifies the view controller that a content view controller will disappear.
    /// This method is well suited as a fucntion to remove targets and listerners that should only be present
    /// when the content view controller is on screen.
    ///
    /// - Parameters:
    ///   - viewController: View controller disappearing.
    ///   - animated: Indicates whether the disappearance is animated.
    open func childWillDisappear(_ child: ViewController, animated: Bool) {
        return
    }

    /// Notifies the view controller that a content view controller did disappear.
    ///
    /// - Parameters:
    ///   - viewController: Content view controller disappearad.
    ///   - animated: Indicates whether the disappearance was animated.
    open func childDidDisappear(_ child: ViewController, animated: Bool) {
        return
    }
}

internal extension StateViewController {

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

        for viewController in children where excluded.contains(viewController) == false {

            // Invoke the appropriate callback method
            if isAppearing {
                childWillAppear(viewController, animated: animated)
            } else {
                childWillDisappear(viewController, animated: animated)
            }

            #if canImport(UIKit)
            viewController.beginAppearanceTransition(isAppearing, animated: animated)
            #endif
        }
    }

    func forwardEndAppearanceTransition(didAppear: Bool, animated: Bool) {

        // Don't include view controlellers in a state transition.
        // Appearance method forwarding will be performed at a later stage.
        let excluded = viewControllersBeingAdded.union(viewControllersBeingRemoved)

        for viewController in children where excluded.contains(viewController) == false {
            #if canImport(UIKit)
            viewController.endAppearanceTransition()
            #endif

            // Invoke the appropriate callback method
            if didAppear {
                childDidAppear(viewController, animated: animated)
            } else {
                childDidDisappear(viewController, animated: animated)
            }
        }
    }
}
