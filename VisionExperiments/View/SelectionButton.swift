//
//  SelectionButton.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 08/06/21.
//
import UIKit
import Foundation

class SelectionButton: UIButton  {
    
    /// ML Model from respective choice
    let mlModel: MLModels

    init(mlModel: MLModels) {
        self.mlModel = mlModel
        super.init(frame: .zero)
        selectionButtonLayout()
        
    }
    
    /// Button Layout
    func selectionButtonLayout() {
        self.backgroundColor = .orange
        self.layer.cornerRadius = 15
        self.layer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
