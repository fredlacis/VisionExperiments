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
    /// Initializes a selection button
    init(mlModel: MLModels) {
        self.mlModel = mlModel
        super.init(frame: .zero)
        selectionButtonLayout()
        selectionButtonLabelLayout()
    }
    /// Button Layout
    func selectionButtonLayout() {
        self.backgroundColor = .orange
        self.layer.cornerRadius = 15
        self.layer.masksToBounds = true
    }
    /// Button label layout
    func selectionButtonLabelLayout() {
        self.titleLabel?.lineBreakMode = .byCharWrapping
        self.titleLabel?.textAlignment = .center
        self.titleLabel?.textColor = .white
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
