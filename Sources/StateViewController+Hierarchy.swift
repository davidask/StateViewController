#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

internal extension StateViewController {

    func updateHierarchy(of viewControllers: [ViewController]) {

        let previousSubviews = childContainerView.subviews

        for (index, viewController) in viewControllers.enumerated() {
            viewController.view.translatesAutoresizingMaskIntoConstraints = true
            #if canImport(UIKit)
            viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            viewController.view.bounds.size = childContainerView.bounds.size
            viewController.view.center = childContainerView.center
            childContainerView.insertSubview(viewController.view, at: index)
            #elseif canImport(AppKit)
            viewController.view.autoresizingMask = [.width, .height]
            viewController.view.frame = childContainerView.bounds
            childContainerView.addSubview(viewController.view)
            #endif
        }

        // Only proceed if the previous subviews of the content view controller container view
        // differ from the new subviews
        guard previousSubviews.elementsEqual(childContainerView.subviews) == false else {
            return
        }

        dispatchStateEvent(.didChangeHierarhcy)

        // Tell everyone we're updating the view hierarchy
        NotificationCenter.default.post(name: .stateViewControllerDidChangeViewHierarchy, object: self)

        #if canImport(UIKit)
        // Make sure that contentInsets for scroll views are updated as we go, in case we're targeting
        // iOS 10 or below.
        triggerAutomaticAdjustmentOfScrollViewInsetsIfNeeded()
        #endif
    }

    #if canImport(UIKit)
    /// Prompts the encloding `UINavigationController` and `UITabBarController` to layout their subviews,
    /// triggering them to adjust the scrollview insets
    func triggerAutomaticAdjustmentOfScrollViewInsetsIfNeeded() {
        guard #available(iOS 11, macCatalyst 11, tvOS 11, *) else {
            if automaticallyAdjustsScrollViewInsets {
                navigationController?.view.setNeedsLayout()
                tabBarController?.view.setNeedsLayout()
            }
            return
        }
    }
    #endif

    /// Adds a content view controller to the state view controller
    ///
    /// - Parameters:
    ///   - viewController: View controller to add
    ///   - animated: Whether part of an animated transition
    func addChild(_ child: ViewController, animated: Bool) {

        guard viewControllersBeingAdded.contains(child) == false else {
            return
        }

        addChild(child)

        // If we're not in an appearance transition, forward appearance methods.
        // If we are, appearance methods will be forwarded at a later time
        if isInAppearanceTransition == false {
            childWillAppear(child, animated: animated)
            dispatchStateEvent(.contentWillAppear(child))
            #if canImport(UIKit)
            child.beginAppearanceTransition(true, animated: animated)
            #endif
        }

        viewControllersBeingAdded.insert(child)
    }

    func didAddChild(_ child: ViewController, animated: Bool) {

        guard viewControllersBeingAdded.contains(child) else {
            return
        }

        // If we're not in an appearance transition, forward appearance methods.
        // If we are, appearance methods will be forwarded at a later time
        if isInAppearanceTransition == false {
            dispatchStateEvent(.contentDidAppear(child))
            #if canImport(UIKit)
            child.endAppearanceTransition()
            #endif
            childDidAppear(child, animated: animated)
        }

        #if canImport(UIKit)
        child.didMove(toParent: self)
        #endif
        viewControllersBeingAdded.remove(child)
    }

    func willRemoveChild(_ child: ViewController, animated: Bool) {

        guard viewControllersBeingRemoved.contains(child) == false else {
            return
        }

        #if canImport(UIKit)
        child.willMove(toParent: nil)
        #endif

        // If we're not in an appearance transition, forward appearance methods.
        // If we are, appearance methods will be forwarded at a later time
        if isInAppearanceTransition == false {
            childWillDisappear(child, animated: animated)
            dispatchStateEvent(.contentWillDisappear(child))
            #if canImport(UIKit)
            child.beginAppearanceTransition(false, animated: animated)
            #endif
        }

        viewControllersBeingRemoved.insert(child)
    }

    func removeChild(_ child: ViewController, animated: Bool) {

        guard viewControllersBeingRemoved.contains(child) else {
            return
        }

        child.view.removeFromSuperview()
        NotificationCenter.default.post(name: .stateViewControllerDidChangeViewHierarchy, object: self)

        // If we're not in an appearance transition, forward appearance methods.
        // If we are, appearance methods will be forwarded at a later time
        if isInAppearanceTransition == false {
            dispatchStateEvent(.contentDidDisappear(child))
            #if canImport(UIKit)
            child.endAppearanceTransition()
            #endif
            childDidDisappear(child, animated: animated)
        }

        child.removeFromParent()
        viewControllersBeingRemoved.remove(child)
    }
}
