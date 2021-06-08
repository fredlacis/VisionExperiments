//
//  UIViewExtensions.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 08/06/21.
//
import UIKit
import Foundation

extension UIView {
    
    /// Custom shape used in UI
    func customShapeLayout() {
        self.backgroundColor = .orange
        self.layer.cornerRadius = 15
        self.layer.masksToBounds = true
    }
}
