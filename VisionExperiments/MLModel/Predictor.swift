
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


class Predictor {
    
    /// Action classifier MLModel
    private let classifier: ActionClassifier
    
    /// Referenced action to detect
    let availableMLModels: AvailableMLModels
    
    /// Model configuration
    let config = MLModelConfiguration()

    /// Vision body pose request
    private let humanBodyPoseRequest = VNDetectHumanBodyPoseRequest()
    
    /// The prediction window size specified on the Model Metadata
    private let predictionWindowSize = 15
    
    init(availableMLModels: AvailableMLModels) {
        self.availableMLModels = availableMLModels
        
        /// Set classifier for respective action
        do {
            classifier = try ActionClassifier(configuration: config, availableMLModels: AvailableMLModels(rawValue: availableMLModels.rawValue)!)
        } catch {
            print("Error on creating JugglingClassifier. | Message: \(error)")
            fatalError("Couldn't create JugglingClassifier")
        }
        /// restricts the window to the predictWindowSize
        posesWindow.reserveCapacity(predictionWindowSize)
    }
    
    /// A rotation window to save the last 60 poses from the past 2 seconds
    var posesWindow: [VNRecognizedPointsObservation?] = []
    
    /// Allows a prediction to be made when the window is full
    public var isReadyToPredict: Bool {
        posesWindow.count == predictionWindowSize
    }
    
    /// Frame processing
    public func processFrame(_ sampleBuffer: CMSampleBuffer) -> [VNHumanBodyPoseObservation] {
        /// Perform Vision body pose request
        let framePoses = extractPoses(from: sampleBuffer)
        
        /// Should het here the most proiminent person, for now I'll just get the first of the array
        if !framePoses.isEmpty, let firstPose = framePoses.first {
            posesWindow.append(firstPose)
        }
        
        return framePoses
    }
    
    /// Predict juggling action from MLMultiArray
    public func makePrediction() throws -> DetectedAction {
        
        /// Prepare model input: convert each pose to a multi-array, and concatenate multi-arrays
        let poseMultiArrays: [MLMultiArray] = try posesWindow.map { person in
            guard let person = person else {
                return try zeroPaddedMultiArray()
            }
            return try person.keypointsMultiArray()
        }
        
        /// Concatenates all the MLMultiArray into one
        let modelInput = MLMultiArray(concatenating: poseMultiArrays, axis: 0, dataType: .float)
        
        /// Makes the prediction with the Action Classifier Model
        let preditcions = try classifier.prediction(poses: modelInput)
        
        /// Reset the poses window
        posesWindow = []
        
        /// Prediction result
        let output = DetectedAction(action: Action(rawValue: preditcions.label) ?? .other, confidence: (preditcions.labelProbabilities[preditcions.label] ?? 0))
        
        return output
    }
}

//MARK: - Predictor Support Methods
extension Predictor {
    
    /// Receives a CMSampleBuffer and returns the Human Poses in it
    func extractPoses(from sampleBuffer: CMSampleBuffer) -> [VNHumanBodyPoseObservation] {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])
        
        do {
            try handler.perform([humanBodyPoseRequest])
            
            guard let results = humanBodyPoseRequest.results, !results.isEmpty else { return [] }
            
            return results
            
        } catch {
            print("Error on extracting poses from buffer. | Message: \(error)")
            fatalError()
        }
    }
    
    func zeroPaddedMultiArray() throws -> MLMultiArray {
        /// Creates a MLMultiArray with the size specified on the Model's Predictions tab
        let array = try MLMultiArray(shape: [1, 3, 18], dataType: MLMultiArrayDataType.float32)
        
        /// Fills it with 0s
        for i in 0..<array.count {
            array[i] = NSNumber(value: 0)
        }
        
        return array
    }
}
