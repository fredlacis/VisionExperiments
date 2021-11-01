//
//  UIIMageExtensions.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 08/06/21.
//
import UIKit
import Foundation

extension UIImageView {
    /// Retrieve a Image by it's name
    func addImage(name: String) {
        /// Case Image does not Exists
        guard let uiImage = UIImage(named: name) else { return self.backgroundColor = .white }
        /// Returns Chosen UIImage
        return self.image = uiImage
    }
}
