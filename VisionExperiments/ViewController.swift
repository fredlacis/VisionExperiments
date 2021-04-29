//
//  ViewController.swift
//  VisionExperiments
//
//  Created by Frederico Lacis de Carvalho on 28/04/21.
//

import UIKit

class ViewController: UIViewController {
    
    private var cameraViewController: CameraViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the camera view controller to the view
        cameraViewController = CameraViewController()
        cameraViewController.view.frame = view.bounds
        addChild(cameraViewController)
        cameraViewController.beginAppearanceTransition(true, animated: true)
        view.addSubview(cameraViewController.view)
        cameraViewController.endAppearanceTransition()
        cameraViewController.didMove(toParent: self)
    }


}

