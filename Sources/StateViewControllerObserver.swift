#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public protocol AnyStateViewControllerObserver: AnyObject {
    func remove()
}

public class StateViewControllerObserver<T: Equatable>: AnyStateViewControllerObserver {

    public typealias EventHandler = (StateViewControllerObserver<T>.Event) -> Void

    public enum Event {
        case willTransitionTo(nextState: T, animated: Bool)
        case didTransitionFrom(previousState: T?, animated: Bool)

        case didChangeHierarhcy

        #if canImport(UIKit)
        case contentWillAppear(UIViewController)
        case contentDidAppear(UIViewController)

        case contentWillDisappear(UIViewController)
        case contentDidDisappear(UIViewController)
        #elseif canImport(AppKit)
        case contentWillAppear(NSViewController)
        case contentDidAppear(NSViewController)

        case contentWillDisappear(NSViewController)
        case contentDidDisappear(NSViewController)
        #endif
    }

    private weak var stateViewController: StateViewController<T>?

    private let eventHandler: EventHandler

    internal init(stateViewController: StateViewController<T>, eventHandler: @escaping EventHandler) {
        self.eventHandler = eventHandler
        self.stateViewController = stateViewController
    }

    public func remove() {
        stateViewController?.removeStateObserver(self)
    }

    internal func invoke(with event: Event) {
        eventHandler(event)
    }
}

extension StateViewControllerObserver: Equatable {

    public static func == (lhs: StateViewControllerObserver, rhs: StateViewControllerObserver) -> Bool {
        return lhs === rhs
    }
}

public extension StateViewController {
    func addStateObserver(
        _ eventHandler: @escaping StateViewControllerObserver<State>.EventHandler
    ) -> StateViewControllerObserver<State> {

        let observer = StateViewControllerObserver(stateViewController: self, eventHandler: eventHandler)

        observers.append(observer)

        return observer
    }

    internal func removeStateObserver(_ observerToRemove: StateViewControllerObserver<State>) {
        observers = observers.filter { observer in
            observer != observerToRemove
        }
    }

    internal func dispatchStateEvent(_ event: StateViewControllerObserver<State>.Event) {
        for observer in observers {
            observer.invoke(with: event)
        }
    }
}
