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

    @IBOutlet var activityIndicator: UIActivityIndicatorView!

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
            activityIndicator.transform = CGAffineTransform.identity.scaledBy(x: 3, y: 3)
        }
    }

    func stateTransitionDidEnd(isAppearing: Bool) {
        view.alpha = 1
        activityIndicator.transform = .identity
    }

    func animateAlongsideStateTransition(isAppearing: Bool) {
        if isAppearing {
            view.alpha = 1
            activityIndicator.transform = .identity
        } else {
            view.alpha = 0
            activityIndicator.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
        }
    }

    func stateTransitionDelay(isAppearing: Bool) -> TimeInterval {
        return isAppearing ? 0 : 0.5
    }
}
