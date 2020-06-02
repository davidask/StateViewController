//
//  TableViewController.swift
//  StateViewControllerExample
//
//  Created by David Ask on 2018-08-16.
//  Copyright © 2018 Formbound. All rights reserved.
//

import StateViewController
import UIKit

class TableViewController: UITableViewController {

    var comments: [Comment] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {

        let comment = comments[indexPath.row]

        cell.textLabel?.text = comment.name
        cell.detailTextLabel?.text = comment.body
    }
}
//
//
//extension TableViewController: StateViewControllerTransitioning {
//
//    func stateTransitionDuration(isAppearing: Bool) -> TimeInterval {
//        return 0.25
//    }
//
//    func stateTransitionWillBegin(isAppearing: Bool) {
//        if isAppearing {
//            view.alpha = 0
//            view.transform = CGAffineTransform.identity.scaledBy(x: 0.95, y: 0.95)
//        }
//    }
//
//    func stateTransitionDidEnd(isAppearing: Bool) {
//        view.alpha = 1
//        view.transform = .identity
//    }
//
//    func animateAlongsideStateTransition(isAppearing: Bool) {
//        if isAppearing {
//            view.alpha = 1
//            view.transform = .identity
//        } else {
//            view.alpha = 0
//            view.transform = CGAffineTransform.identity.scaledBy(x: 0.95, y: 0.95)
//        }
//    }
//
//    func stateTransitionDelay(isAppearing: Bool) -> TimeInterval {
//        return 0
//    }
//}
