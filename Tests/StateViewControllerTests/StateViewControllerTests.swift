#if canImport(UIKit)

@testable import StateViewController
import XCTest

final class StateViewControllerTests: XCTestCase {

    func testNonanimatedTransitionFinishesAndReportsPreviousState() {
        let controller = TestStateViewController()
        _ = controller.view

        controller.setNeedsStateTransition(to: .first, animated: false)

        XCTAssertFalse(controller.isTransitioningBetweenStates)
        XCTAssertEqual(controller.transitions.count, 1)
        XCTAssertNil(controller.transitions[0].from)
        XCTAssertEqual(controller.transitions[0].to, .first)

        controller.setNeedsStateTransition(to: .second, animated: false)

        XCTAssertFalse(controller.isTransitioningBetweenStates)
        XCTAssertEqual(controller.transitions.count, 2)
        XCTAssertEqual(controller.transitions[1].from, .first)
        XCTAssertEqual(controller.transitions[1].to, .second)
        XCTAssertIdentical(controller.children.first, controller.secondChild)
    }

    func testOffscreenTransitionsDoNotForwardAppearanceCallbacks() {
        let controller = TestStateViewController()
        _ = controller.view

        controller.setNeedsStateTransition(to: .first, animated: false)
        controller.setNeedsStateTransition(to: .second, animated: false)

        XCTAssertEqual(controller.firstChild.appearanceEvents, [])
        XCTAssertEqual(controller.secondChild.appearanceEvents, [])
        XCTAssertEqual(controller.childAppearanceEvents, [])
    }

    func testTransitionAfterDisappearanceDoesNotForwardAppearanceCallbacks() {
        let controller = TestStateViewController()

        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()

        controller.firstChild.appearanceEvents = []
        controller.childAppearanceEvents = []
        controller.setNeedsStateTransition(to: .second, animated: false)

        XCTAssertEqual(controller.firstChild.appearanceEvents, [])
        XCTAssertEqual(controller.secondChild.appearanceEvents, [])
        XCTAssertEqual(controller.childAppearanceEvents, [])
    }

    func testInitialNonanimatedAppearanceIsForwardedOnce() {
        let parent = UIViewController()
        let controller = TestStateViewController()
        _ = parent.view
        parent.addChild(controller)
        parent.view.addSubview(controller.view)

        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.didMove(toParent: parent)

        XCTAssertTrue(controller.wasMovingToParentInViewWillAppear)
        XCTAssertEqual(controller.firstChild.appearanceEvents, ["willAppear", "didAppear"])
        XCTAssertEqual(
            controller.childAppearanceEvents,
            ["first.willAppear", "first.didAppear"]
        )
        XCTAssertFalse(controller.isTransitioningBetweenStates)
    }

    func testInterruptedInitialAppearanceDoesNotReportDidAppear() {
        let controller = TestStateViewController()

        controller.beginAppearanceTransition(true, animated: false)
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()

        XCTAssertEqual(
            controller.firstChild.appearanceEvents,
            ["willAppear", "willDisappear", "didDisappear"]
        )
        XCTAssertEqual(
            controller.childAppearanceEvents,
            ["first.willAppear", "first.willDisappear", "first.didDisappear"]
        )
        XCTAssertFalse(controller.isTransitioningBetweenStates)
    }

    func testChildAppearanceCallbackCanSynchronouslyChangeState() {
        let controller = TestStateViewController()
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.onChildWillDisappear = { [weak controller] in
            controller?.setNeedsStateTransition(to: .second, animated: false)
        }

        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()

        XCTAssertEqual(
            controller.firstChild.appearanceEvents,
            ["willAppear", "didAppear", "willDisappear", "didDisappear"]
        )
        XCTAssertEqual(controller.currentState, .second)
        XCTAssertFalse(controller.isTransitioningBetweenStates)
    }

    func testDidTransitionRequestSupersedesOlderPendingState() {
        let controller = TestStateViewController()
        controller.usesSharedChild = true
        controller.onDidTransition = { [weak controller] state in
            if state == .first {
                controller?.setNeedsStateTransition(to: .newest, animated: false)
            }
        }

        controller.beginAppearanceTransition(true, animated: false)
        controller.setNeedsStateTransition(to: .pending, animated: false)
        controller.endAppearanceTransition()

        XCTAssertEqual(controller.currentState, .newest)
        XCTAssertEqual(controller.transitions.map { $0.to }, [.first, .newest])
        XCTAssertFalse(controller.isTransitioningBetweenStates)
    }

    func testChildUsesContainerBoundsCoordinateSpace() {
        let controller = TestStateViewController()
        _ = controller.view
        controller.childContainerView.bounds = CGRect(x: 10, y: 20, width: 100, height: 200)
        controller.childContainerView.center = CGPoint(x: 250, y: 300)

        controller.setNeedsStateTransition(to: .first, animated: false)

        XCTAssertEqual(controller.firstChild.view.center.x, 60, accuracy: 0.001)
        XCTAssertEqual(controller.firstChild.view.center.y, 120, accuracy: 0.001)
        XCTAssertEqual(controller.firstChild.view.bounds.size.width, 100, accuracy: 0.001)
        XCTAssertEqual(controller.firstChild.view.bounds.size.height, 200, accuracy: 0.001)
    }

    func testPendingAnimatedAdditionJoinsParentAppearance() {
        let controller = TestStateViewController()
        controller.firstChild.transitionDuration = 0.05

        controller.setNeedsStateTransition(to: .first, animated: true)
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()

        XCTAssertEqual(controller.firstChild.appearanceEvents, ["willAppear", "didAppear"])
        XCTAssertEqual(
            controller.childAppearanceEvents,
            ["first.willAppear", "first.didAppear"]
        )

        let completed = expectation(description: "Animation completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1)
        XCTAssertFalse(controller.isTransitioningBetweenStates)
    }

    func testStaleAnimationCannotCompleteNewerTransitionForReusedChild() {
        let controller = TestStateViewController()
        controller.firstChild.transitionDuration = 0.1
        controller.secondChild.transitionDuration = 0.1

        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.setNeedsStateTransition(to: .second, animated: true)
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        controller.setNeedsStateTransition(to: .first, animated: true)

        let completed = expectation(description: "Animations completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1)

        XCTAssertEqual(controller.currentState, .first)
        XCTAssertIdentical(controller.children.first, controller.firstChild)
        XCTAssertEqual(controller.transitions.map { $0.to }, [.first, .second, .first])
        XCTAssertFalse(controller.isTransitioningBetweenStates)
    }
}

private enum TestState: Equatable {
    case first
    case second
    case pending
    case newest
}

private final class TestStateViewController: StateViewController<TestState> {

    struct Transition {
        let from: TestState?
        let to: TestState
        let animated: Bool
    }

    let firstChild = RecordingViewController(identifier: "first")
    let secondChild = RecordingViewController(identifier: "second")
    let pendingChild = RecordingViewController(identifier: "pending")
    let newestChild = RecordingViewController(identifier: "newest")

    var appearanceState = TestState.first
    var usesSharedChild = false
    var wasMovingToParentInViewWillAppear = false
    var transitions: [Transition] = []
    var childAppearanceEvents: [String] = []
    var onDidTransition: ((TestState) -> Void)?
    var onChildWillDisappear: (() -> Void)?

    override func loadAppearanceState() -> TestState {
        appearanceState
    }

    override func viewWillAppear(_ animated: Bool) {
        wasMovingToParentInViewWillAppear = isMovingToParent
        super.viewWillAppear(animated)
    }

    override func children(for state: TestState) -> [UIViewController] {
        if usesSharedChild {
            return [firstChild]
        }

        switch state {
        case .first:
            return [firstChild]
        case .second:
            return [secondChild]
        case .pending:
            return [pendingChild]
        case .newest:
            return [newestChild]
        }
    }

    override func didTransition(from previousState: TestState?, animated: Bool) {
        transitions.append(Transition(from: previousState, to: currentState, animated: animated))
        onDidTransition?(currentState)
    }

    override func childWillAppear(_ child: UIViewController, animated: Bool) {
        childAppearanceEvents.append("\(identifier(for: child)).willAppear")
    }

    override func childDidAppear(_ child: UIViewController, animated: Bool) {
        childAppearanceEvents.append("\(identifier(for: child)).didAppear")
    }

    override func childWillDisappear(_ child: UIViewController, animated: Bool) {
        childAppearanceEvents.append("\(identifier(for: child)).willDisappear")
        onChildWillDisappear?()
    }

    override func childDidDisappear(_ child: UIViewController, animated: Bool) {
        childAppearanceEvents.append("\(identifier(for: child)).didDisappear")
    }

    private func identifier(for child: UIViewController) -> String {
        (child as? RecordingViewController)?.identifier ?? "unknown"
    }
}

private final class RecordingViewController: UIViewController {

    let identifier: String
    var appearanceEvents: [String] = []
    var transitionDuration: TimeInterval = 0

    init(identifier: String) {
        self.identifier = identifier
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appearanceEvents.append("willAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearanceEvents.append("didAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appearanceEvents.append("willDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appearanceEvents.append("didDisappear")
    }
}

extension RecordingViewController: StateViewControllerTransitioning {

    func stateTransitionDuration(isAppearing: Bool) -> TimeInterval {
        transitionDuration
    }

    func stateTransitionWillBegin(isAppearing: Bool) {}

    func stateTransitionDidEnd(isAppearing: Bool) {}

    func animateAlongsideStateTransition(isAppearing: Bool) {}

    func stateTransitionDelay(isAppearing: Bool) -> TimeInterval {
        0
    }
}

#endif
