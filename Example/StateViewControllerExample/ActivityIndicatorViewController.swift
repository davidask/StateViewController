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

    @IBOutlet private var activityIndicatorBackground: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicatorBackground.layer.cornerRadius = 10
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
            activityIndicator.transform = CGAffineTransform.identity.scaledBy(x: 3, y: 3)
            activityIndicatorBackground.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
        }
    }

    func stateTransitionDidEnd(isAppearing: Bool) {
        view.alpha = 1
        activityIndicator.transform = .identity
        activityIndicatorBackground.transform = .identity
    }

    func animateAlongsideStateTransition(isAppearing: Bool) {
        if isAppearing {
            view.alpha = 1
            activityIndicator.transform = .identity
            activityIndicatorBackground.transform = .identity
        } else {
            view.alpha = 0
            activityIndicator.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
            activityIndicatorBackground.transform = CGAffineTransform.identity.scaledBy(x: 1.25, y: 1.25)
        }
    }

    func stateTransitionDelay(isAppearing: Bool) -> TimeInterval {
        return isAppearing ? 0 : 0.25
    }
}
