//
//  ActivityIndicatorViewController.swift
//  StateViewControllerExample
//
//  Created by David Ask on 2018-08-16.
//  Copyright © 2018 Formbound. All rights reserved.
//

import StateViewController
import UIKit

class ActivityIndicatorViewController: UIViewController {

    @IBOutlet private var activityIndicator: UIActivityIndicatorView!

    @IBOutlet private var activityIndicatorContainer: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicatorContainer.layer.cornerRadius = 5
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        activityIndicator.startAnimating()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        activityIndicator.stopAnimating()
    }
}

extension ActivityIndicatorViewController: StateViewControllerTransitioning {

    func stateTransitionDuration(isAppearing: Bool) -> TimeInterval {
        return 0.5
    }

    func stateTransitionWillBegin(isAppearing: Bool) {
        if isAppearing {
            view.alpha = 0
            activityIndicatorContainer.transform = CGAffineTransform
                .identity
                .scaledBy(x: 0.5, y: 0.5)
        }
    }

    func stateTransitionDidEnd(isAppearing: Bool) {
        view.alpha = 1
        activityIndicatorContainer.transform = .identity
    }

    func animateAlongsideStateTransition(isAppearing: Bool) {
        if isAppearing {
            view.alpha = 1
            activityIndicatorContainer.transform = .identity
        } else {
            view.alpha = 0
            activityIndicatorContainer.transform = CGAffineTransform
                .identity
                .scaledBy(x: 1.5, y: 1.5)
        }
    }

    func stateTransitionDelay(isAppearing: Bool) -> TimeInterval {
        return isAppearing ? 0 : 0.5
    }
}
