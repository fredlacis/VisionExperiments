//
//  UILabelExtensions.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 06/05/21.
//
import UIKit
import Foundation

extension UILabel {
    
    /// Custom label used in UI
    func customLabelLayout(fontSize: CGFloat, text: String = "") {
        self.textAlignment = .center
        self.textColor = .white
        self.setHelveticaBold(fontSize)
        self.text = text
    }
    
    /// Set font as helvetica bold
    func setHelveticaBold(_ fontSize: CGFloat) {
        self.font = UIFont(name: "HelveticaNeue-Bold", size: fontSize)
    }
}

