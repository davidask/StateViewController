//
//  ListStateViewController.swift
//  StateViewControllerExample
//
//  Created by David Ask on 2018-08-16.
//  Copyright © 2018 Formbound. All rights reserved.
//

import StateViewController
import UIKit

enum ListStateViewControllerState: Equatable {
    case loading
    case ready([Comment])
}

class ListStateViewController: StateViewController<ListStateViewControllerState> {

    lazy var reloadBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .refresh,
        target: self,
        action: #selector(refresh)
    )

    override func awakeFromNib() {
        super.awakeFromNib()

        title = "Comments"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    lazy private var tableViewController: TableViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        return storyboard.instantiateViewController(withIdentifier: "tableViewController") as! TableViewController
    }()

    override func loadAppearanceState() -> ListStateViewControllerState {
        return .loading
    }

    override func contentViewControllers(for state: ListStateViewControllerState) -> [UIViewController] {
        switch state {
        case .loading:

            let storyboard = UIStoryboard(name: "Main", bundle: .main)

            return [
                storyboard.instantiateViewController(withIdentifier: "activityIndicatorController")
            ]
        case .ready:
            return [
                tableViewController
            ]
        }
    }

    override func willTransition(to nextState: ListStateViewControllerState, animated: Bool) {
        switch nextState {
        case .loading:
            navigationItem.setRightBarButton(nil, animated: animated)
        case .ready(let comments):
            navigationItem.setRightBarButton(reloadBarButtonItem, animated: animated)
            tableViewController.comments = comments
        }
    }

    override func didTransition(from previousState: ListStateViewControllerState?, animated: Bool) {
        switch currentState {
        case .loading:
            Comment.loadComments { _, comments in
                guard let comments = comments else {
                    return
                }

                DispatchQueue.main.async {
                    self.setNeedsStateTransition(to: .ready(comments), animated: true)
                }
            }
        case .ready:
            break
        }
    }

    @objc
    func refresh() {
        self.setNeedsStateTransition(to: .loading, animated: true)
    }

}
