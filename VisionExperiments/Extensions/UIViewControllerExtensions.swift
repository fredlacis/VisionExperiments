//
//  UIViewControllerExtensions.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 08/06/21.
//
import UIKit
import Foundation

extension UIViewController {

    /// Presents given view controller in fullscreen
    func presentFullScreen(_ nextVC: UIViewController) {
        nextVC.modalPresentationStyle = .fullScreen
        nextVC.navigationController?.isNavigationBarHidden = false
        self.present(nextVC, animated: true, completion: nil)
    }
    
    /// Dismisses a VC from right to left
    @objc func dismissVC() {
        let transition = CATransition()
        transition.duration = 0.25
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromLeft
        view.window!.layer.add(transition, forKey: kCATransition)
        self.dismiss(animated: false, completion: nil)
    }
    
    @objc func popVC() {
        self.navigationController?.popViewController(animated: true)
    }
}
