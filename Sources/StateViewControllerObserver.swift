
public protocol AnyStateViewControllerObserver : AnyObject, Equatable {
    func remove()
}

public extension AnyStateViewControllerObserver {

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs === rhs
    }

}

public class StateViewControllerObserver<T: Equatable>: AnyStateViewControllerObserver {

    public typealias EventHandler = (StateViewControllerObserver<T>.Event) -> Void

    public enum Event {
        case willTransitionTo(T)
        case didTransitionFrom(T?)
        case didChangeHierarhcy
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



