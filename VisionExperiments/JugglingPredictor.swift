//
//  Predictor.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 29/04/21.
//

import Foundation
import CoreML
import Vision

@available(iOS 14.0, *)

class JugglingPredictor {
    // Juggling Classifier MLModel
    static let jugglingClassifier = JugglingClassifier()
    
    // Predict juggling action from MLMultiArray
    static func makePrediction(modelInput: MLMultiArray) throws -> String {
        
        let preditcions = try jugglingClassifier.prediction(poses: modelInput)
        
        let output = "label: \(preditcions.label), confidence: \(String(describing: preditcions.labelProbabilities[preditcions.label]))"
        
        return output
    }
}
