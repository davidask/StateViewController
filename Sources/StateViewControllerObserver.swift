
public protocol AnyStateViewControllerObserver : AnyObject {
    func remove()
}

public class StateViewControllerObserver<T: Equatable>: AnyStateViewControllerObserver {

    public typealias EventHandler = (StateViewControllerObserver<T>.Event) -> Void

    public enum Event {
        case willTransitionTo(nextState: T, animated: Bool)
        case didTransitionFrom(previousState: T?, animated: Bool)

        case didChangeHierarhcy

        case contentWillAppear(UIViewController)
        case contentDidAppear(UIViewController)

        case contentWillDisappear(UIViewController)
        case contentDidDisappear(UIViewController)
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



