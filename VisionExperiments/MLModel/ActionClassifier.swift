//
// ActionClassifier.swift
//
//
//

import CoreML


//MARK: - Model Prediction Input Type
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class ActionClassifierInput : MLFeatureProvider {

    /// A sequence of body poses to classify. Its multiarray encoding uses the first dimension to index time over 15 frames. The second dimension indexes x, y, and confidence of pose keypoint locations. The last dimension indexes the keypoint type, ordered as: nose, neck, right shoulder, right elbow, right wrist, left shoulder, left elbow, left wrist, right hip, right knee, right ankle, left hip, left knee, left ankle, right eye, left eye, right ear, left ear as 15 × 3 × 18 3-dimensional array of floats
    var poses: MLMultiArray

    var featureNames: Set<String> {
        get {
            return ["poses"]
        }
    }
    
    /// Get feature value from poses
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "poses") {
            return MLFeatureValue(multiArray: poses)
        }
        return nil
    }
    
    init(poses: MLMultiArray) {
        self.poses = poses
    }
}


//MARK: - Model Prediction Output Type
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class ActionClassifierOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider


    /// Probability of each category as dictionary of strings to doubles
    lazy var labelProbabilities: [String : Double] = {
        [unowned self] in return self.provider.featureValue(for: "labelProbabilities")!.dictionaryValue as! [String : Double]
    }()

    /// Most likely action category as string value
    lazy var label: String = {
        [unowned self] in return self.provider.featureValue(for: "label")!.stringValue
    }()

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(labelProbabilities: [String : Double], label: String) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["labelProbabilities" : MLFeatureValue(dictionary: labelProbabilities as [AnyHashable : NSNumber]), "label" : MLFeatureValue(string: label)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


//MARK: - Class for Model Loading and Prediction
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class ActionClassifier {
    
    /// ML Model
    let model: MLModel
    
    /// Referenced Action
    let availableMLModels: AvailableMLModels
    
    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)

        // TO DO!!
        return bundle.url(forResource: "JugglingClassifier", withExtension:"mlmodelc")!
    }

    init(model: MLModel, availableMLModels: AvailableMLModels) {
        self.model = model
        self.availableMLModels = availableMLModels
    }

    /**
        Construct ActionClassifier instance by automatically loading the model from the app's bundle and receiving action
    */
    @available(*, deprecated, message: "Use init(configuration:) instead and handle errors appropriately.")
    convenience init(availableMLModels: AvailableMLModels) {
        try! self.init(contentsOf: type(of:self).urlOfModelInThisBundle, availableMLModels: availableMLModels)
    }

    /**
        Construct a model with configuration

        - parameters:
            - configuration: the desired model configuration
            - action: referenced action to detect

        - throws: an NSError object that describes the problem
    */
    convenience init(configuration: MLModelConfiguration, availableMLModels: AvailableMLModels) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration, availableMLModels: availableMLModels)
    }

    /**
        Construct ActionClassifier instance with explicit path to mlmodelc file
        - parameters:
            - configuration: the desired model configuration
            - action: referenced action to detect

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, availableMLModels: AvailableMLModels) throws {
        try self.init(model: MLModel(contentsOf: modelURL), availableMLModels: availableMLModels)
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
            - modelURL: the file url of the model
            - configuration: the desired model configuration
            - action: referenced action
     
        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration, availableMLModels: AvailableMLModels) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration), availableMLModels: availableMLModels)
    }
    /**
        Construct ActionClassifier instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
            - configuration: the desired model configuration
            - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
            - action : referenced action
    */
    
    
    // TO DO CHEK: Fix
//    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
//    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<ActionClassifier, Error>) -> Void) {
//        return self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
//    }

    /**
        Construct ActionClassifier instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<ActionClassifier, Error>) -> Void) {
        MLModel.__loadContents(of: modelURL, configuration: configuration) { (model, error) in
            if let error = error {
                handler(.failure(error))
            } else if let model = model {
                handler(.success(ActionClassifier(model: model, availableMLModels: self.availableMLModels)))
            } else {
                fatalError("SPI failure: -[MLModel loadContentsOfURL:configuration::completionHandler:] vends nil for both model and error.")
            }
        }
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as ActionClassifierInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as ActionClassifierOutput
    */
    func prediction(input: ActionClassifierInput) throws -> ActionClassifierOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as ActionClassifierInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as ActionClassifierOutput
    */
    func prediction(input: ActionClassifierInput, options: MLPredictionOptions) throws -> ActionClassifierOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return ActionClassifierOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        - parameters:
            - poses: A sequence of body poses to classify. Its multiarray encoding uses the first dimension to index time over 15 frames. The second dimension indexes x, y, and confidence of pose keypoint locations. The last dimension indexes the keypoint type, ordered as: nose, neck, right shoulder, right elbow, right wrist, left shoulder, left elbow, left wrist, right hip, right knee, right ankle, left hip, left knee, left ankle, right eye, left eye, right ear, left ear as 15 × 3 × 18 3-dimensional array of floats

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as JugglingClassifierOutput
    */
    func prediction(poses: MLMultiArray) throws -> ActionClassifierOutput {
        let input_ = ActionClassifierInput(poses: poses)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        - parameters:
           - inputs: the inputs to the prediction as [JugglingClassifierInput]
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [JugglingClassifierOutput]
    */
    func predictions(inputs: [ActionClassifierInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [ActionClassifierOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [ActionClassifierOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  ActionClassifierOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
