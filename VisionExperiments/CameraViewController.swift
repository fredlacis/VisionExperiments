//
//  CameraViewController.swift
//  VisionExperiments
//
//  Created by Frederico Lacis de Carvalho on 29/04/21.
//

import UIKit
import AVFoundation
import Vision

protocol CameraViewControllerOutputDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation)
}

class CameraViewController: UIViewController {
    
    // Delegate
    weak var outputDelegate: CameraViewControllerOutputDelegate?
    
    // Camera thread
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInitiated,
                                                     attributes: [], autoreleaseFrequency: .workItem)
    
    // Classifier label
    private let classifierLabel = UILabel()
    
    // High Score label
    private let highScoreLabel = UILabel()
    
    // Confidence label
    private let confidenceLabel = UILabel()
    
    // Best label
    private let bestLabel = UILabel()
    
    // Counter label
    private let counterLabel = UILabel()
    
    // Counter
    private var count: Int = 0
    
    // High score
    private var highScore: Int = 0
    
    // Current confidence
    private var currentConfidence: Double = 0
    
    // A view that exibits the body joints
    private let jointSegmentView = JointSegmentView()
    
    // A view that exibits the body bounding box
    private let playerBoundingBox = BoundingBoxView()
    
    // The predictor for detecting human poses and tell if it's Juggling or not
    let predictor = JugglingPredictor()
    
    // Camera Postion
    var cameraPosition: AVCaptureDevice.Position = .back
    
    // Flip Camera Button
    let flipCameraButton = UIButton()
    
    // Live camera feed management
    private var cameraFeedView: CameraFeedView!
    private var cameraFeedSession: AVCaptureSession?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setupView()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop capture session if it's running
        cameraFeedSession?.stopRunning()
    }
}


// MARK: - Camera Output Live Video Processor Extension
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // Predictes result from camera output
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Delagete method
        outputDelegate?.cameraViewController(self, didReceiveBuffer: sampleBuffer, orientation: .up)
        
        // Frame processor
        let detectPlayerRequest = predictor.processFrame(sampleBuffer)

        if let result = detectPlayerRequest.first {
//            print("Body deceted: \(result.confidence)")
            let box = humanBoundingBox(for: result)
            let boxView = playerBoundingBox
            DispatchQueue.main.async {
                let inset: CGFloat = -20.0
                let viewRect = self.viewRectForVisionRect(box).insetBy(dx: inset, dy: inset)
                self.updateBoundingBox(boxView, withRect: viewRect)
                let normalizedFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
                self.jointSegmentView.frame = self.viewRectForVisionRect(normalizedFrame)
            }
        }
        
        // Prediction process
        if predictor.isReadyToPredict {
            do {
                let prediction = try predictor.makePrediction()
                
                // Detects which action is been performed
                switch prediction.getAction() {
                
                case .juggling(let confidence):
                    count+=1
                    currentConfidence = confidence
                    // Checks if it beats high score
                    highScore = highScore <= count ? count : highScore
                    
                case .other(let confidence):
                    count = 0
                    currentConfidence = confidence
                }
                
                // Updates main theread UI
                DispatchQueue.main.async {
                                        
                    // Confirm juggling with basic filter
                    if self.count >= 3 {
                        self.counterLabel.text = "\(self.count)"
                        self.highScoreLabel.text = "\(self.highScore)"
                    }
                    else {
                        self.counterLabel.text = ""
                    }
                    
                    // Prediction
                    self.classifierLabel.text = "\(prediction.getLabel() == "Juggling" ? "Juggling" : "Not Juggling")"

                    // Confidence
                    self.confidenceLabel.text = "\(self.currentConfidence)%"
                }
            } catch {
                debugPrint(error)
            }
        }
    }
}

// MARK: - Vision Supporting Methods
extension CameraViewController {
    
    func getBodyJointsFor(observation: VNHumanBodyPoseObservation) -> ([VNHumanBodyPoseObservation.JointName: CGPoint]) {
        var joints = [VNHumanBodyPoseObservation.JointName: CGPoint]()
        guard let identifiedPoints = try? observation.recognizedPoints(.all) else {
            return joints
        }
        for (key, point) in identifiedPoints {
            guard point.confidence > 0.1 else { continue }
            if jointsOfInterest.contains(key) {
    //        print("Key: \(key), Location: \(point.location)")
                joints[key] = point.location
            }
        }
        return joints
    }
    
    func updateBoundingBox(_ boundingBox: BoundingBoxView, withRect rect: CGRect?) {
        // Update the frame for player bounding box
        boundingBox.frame = rect ?? .zero
        boundingBox.perform(transition: (rect == nil ? .fadeOut : .fadeIn), duration: 0.1)
    }
    
    func humanBoundingBox(for observation: VNHumanBodyPoseObservation) -> CGRect {
        let bodyPoseDetectionMinConfidence: VNConfidence = 0.6
        let bodyPoseRecognizedPointMinConfidence: VNConfidence = 0.1
        
        var box = CGRect.zero
        var normalizedBoundingBox = CGRect.null
        // Process body points only if the confidence is high.
        guard observation.confidence > bodyPoseDetectionMinConfidence, let points = try? observation.recognizedPoints(forGroupKey: .all) else {
            return box
        }
        // Only use point if human pose joint was detected reliably.
        for (_, point) in points where point.confidence > bodyPoseRecognizedPointMinConfidence {
            normalizedBoundingBox = normalizedBoundingBox.union(CGRect(origin: point.location, size: .zero))
        }
        if !normalizedBoundingBox.isNull {
            box = normalizedBoundingBox
        }
//        // Fetch body joints from the observation and overlay them on the player.
        let joints = getBodyJointsFor(observation: observation)
        DispatchQueue.main.async {
            self.jointSegmentView.joints = joints
        }

        return box
    }
    
    // This helper function is used to convert rects returned by Vision to the video content rect coordinates.
    //
    // The video content rect (camera preview or pre-recorded video)
    // is scaled to fit into the view controller's view frame preserving the video's aspect ratio
    // and centered vertically and horizontally inside the view.
    //
    // Vision coordinates have origin at the bottom left corner and are normalized from 0 to 1 for both dimensions.
    //
    func viewRectForVisionRect(_ visionRect: CGRect) -> CGRect {
        let flippedRect = visionRect.applying(CGAffineTransform.verticalFlip)
        let viewRect: CGRect
        
        viewRect = cameraFeedView.viewRectConverted(fromNormalizedContentsRect: flippedRect)
        
        return viewRect
    }
    
    // This helper function is used to convert points returned by Vision to the video content rect coordinates.
    //
    // The video content rect (camera preview or pre-recorded video)
    // is scaled to fit into the view controller's view frame preserving the video's aspect ratio
    // and centered vertically and horizontally inside the view.
    //
    // Vision coordinates have origin at the bottom left corner and are normalized from 0 to 1 for both dimensions.
    //
    func viewPointForVisionPoint(_ visionPoint: CGPoint) -> CGPoint {
        let flippedPoint = visionPoint.applying(CGAffineTransform.verticalFlip)
        let viewPoint: CGPoint
        
        viewPoint = cameraFeedView.viewPointConverted(fromNormalizedContentsPoint: flippedPoint)
        
        return viewPoint
    }
}

// MARK: - Setup Camera Session Extension
extension CameraViewController {
    
    func setupAVSession() throws {
        // Create device discovery session for a wide angle camera
        let wideAngle = AVCaptureDevice.DeviceType.builtInWideAngleCamera
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [wideAngle], mediaType: .video, position: cameraPosition)
        
        // Select a video device, make an input
        guard let videoDevice = discoverySession.devices.first else {
            throw AppError.captureSessionSetup(reason: "Could not find a wide angle camera device.")
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        // We prefer a 1080p video capture but if camera cannot provide it then fall back to highest possible quality
        if videoDevice.supportsSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        let captureConnection = dataOutput.connection(with: .video)
        captureConnection?.preferredVideoStabilizationMode = .standard
        
        // Always process the frames
        captureConnection?.isEnabled = true
        session.commitConfiguration()
        cameraFeedSession = session
        
        // Get the interface orientaion from window scene to set proper video orientation on capture connection.
        let videoOrientation: AVCaptureVideoOrientation
        switch view.window?.windowScene?.interfaceOrientation {
        case .landscapeRight:
            videoOrientation = .landscapeRight
        default:
            videoOrientation = .portrait
        }
        
        // Create and setup video feed view
        cameraFeedView = CameraFeedView(frame: view.bounds, session: session, videoOrientation: videoOrientation)
        
        // View setup methods
        setupCameraFeedView()
        cameraFeedViewConstraints()
        
        // Starts running camera
        cameraFeedSession?.startRunning()
    }
}

// MARK: - View Setup Extensions
extension CameraViewController {
    
    // Tier 0 - Setup camera feed view UI
    func setupCameraFeedView() {
        view.addSubview(cameraFeedView)
        cameraFeedView.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
    }
    
    // Tier 0.5 - Setup Joint Segment View
    func setupVisionViews() {
        playerBoundingBox.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        playerBoundingBox.backgroundOpacity = 0
        playerBoundingBox.isHidden = false
        view.addSubview(playerBoundingBox)
        view.addSubview(jointSegmentView)
    }
    
    // Tier 1 - Setup classifier label UI
    func setupClassifierLabel() {
        view.addSubview(classifierLabel)
        classifierLabelConstraints()
        classifierLabel.backgroundColor = .orange
        classifierLabel.textAlignment = .center
        classifierLabel.layer.cornerRadius = 15
        classifierLabel.textColor = .white
        classifierLabel.layer.masksToBounds = true
        classifierLabel.setHelveticaBold(fontSize: 20)
    }
    

    // Tier 2 - Setup highscore label UI
    func setupHighScoreLabel() {
        view.addSubview(highScoreLabel)
        highScoreLabelConstraints()
        highScoreLabel.backgroundColor = .orange
        highScoreLabel.textAlignment = .center
        highScoreLabel.layer.cornerRadius = 15
        highScoreLabel.textColor = .white
        highScoreLabel.layer.masksToBounds = true
        highScoreLabel.text = "\(highScore)"
        highScoreLabel.setHelveticaBold(fontSize: 20)
    }
    
    // Tier 3 - Setup confidence label UI
    func setupConficendeLabel() {
        view.addSubview(confidenceLabel)
        confidenceLabelConstraints()
        confidenceLabel.backgroundColor = .orange
        confidenceLabel.textAlignment = .center
        confidenceLabel.layer.cornerRadius = 15
        confidenceLabel.textColor = .white
        confidenceLabel.layer.masksToBounds = true
        confidenceLabel.setHelveticaBold(fontSize: 13)
        confidenceLabel.text = "\(currentConfidence)%"
    }
    
    // Tier 4 - Setup best label UI
    func setupBestLabel() {
        view.addSubview(bestLabel)
        bestLabelConstraints()
        bestLabel.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0)
        bestLabel.textAlignment = .center
        bestLabel.textColor = .orange
        bestLabel.setHelveticaBold(fontSize: 20)
        bestLabel.text = "Best"
    }
    
    // Tier 5 - Setup counter label UI
    func setupCounterLabel() {
        view.addSubview(counterLabel)
        counterLabelConstraints()
        counterLabel.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0)
        counterLabel.textAlignment = .center
        counterLabel.textColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.65)
        counterLabel.font = confidenceLabel.font.withSize(200)
        counterLabel.text = ""
    }
    
    // Tier 6 - Setup Flip Camera Button
    func setupFlipCameraButton() {
        view.addSubview(flipCameraButton)
        flipCameraButtonConstraints()
        flipCameraButton.backgroundColor = .orange
        flipCameraButton.layer.cornerRadius = 15
        flipCameraButton.layer.masksToBounds = true
        flipCameraButton.addTarget(self, action: #selector(flipCamera), for: .touchUpInside)
    }
    
    // Tier 6 - Flip Camera
    @objc func flipCamera() {
        if cameraPosition == .front {
            cameraPosition = .back
            print("oi")
        }
        else {
            cameraPosition = .front
        }
        setupView()
    }
    
    // Tier 0 - Video output view constraints
    func cameraFeedViewConstraints() {
        cameraFeedView.translatesAutoresizingMaskIntoConstraints = false
        cameraFeedView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        cameraFeedView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        cameraFeedView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        cameraFeedView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    // Tier 1 - Classifier label constraints
    func classifierLabelConstraints() {
        classifierLabel.translatesAutoresizingMaskIntoConstraints = false
        classifierLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        classifierLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: view.frame.height*0.15).isActive = true
        classifierLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5).isActive = true
        classifierLabel.heightAnchor.constraint(equalTo: classifierLabel.widthAnchor, multiplier: 0.25).isActive = true
    }
    
    // Tier 2 - High score label constrains
    func highScoreLabelConstraints() {
        highScoreLabel.translatesAutoresizingMaskIntoConstraints = false
        highScoreLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -view.frame.width*0.05).isActive = true
        highScoreLabel.centerYAnchor.constraint(equalTo: classifierLabel.centerYAnchor).isActive = true
        highScoreLabel.heightAnchor.constraint(equalTo: classifierLabel.heightAnchor).isActive = true
        highScoreLabel.widthAnchor.constraint(equalTo: highScoreLabel.heightAnchor).isActive = true
    }
    
    // Tier 3 - Confidence label constraints
    func confidenceLabelConstraints() {
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        confidenceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        confidenceLabel.bottomAnchor.constraint(equalTo: classifierLabel.topAnchor, constant: 15).isActive = true
        confidenceLabel.widthAnchor.constraint(equalTo: classifierLabel.widthAnchor, multiplier: 0.5).isActive = true
        confidenceLabel.heightAnchor.constraint(equalTo: confidenceLabel.widthAnchor, multiplier: 0.3).isActive = true
    }
    
    // Tier 4 - Confidence label constraints
    func bestLabelConstraints() {
        bestLabel.translatesAutoresizingMaskIntoConstraints = false
        bestLabel.centerXAnchor.constraint(equalTo: highScoreLabel.centerXAnchor).isActive = true
        bestLabel.bottomAnchor.constraint(equalTo: highScoreLabel.topAnchor, constant: 15).isActive = true
        bestLabel.widthAnchor.constraint(equalTo: highScoreLabel.widthAnchor).isActive = true
        bestLabel.heightAnchor.constraint(equalTo: bestLabel.widthAnchor).isActive = true
    }
    
    // Tier 5 - Counter label contraints
    func counterLabelConstraints() {
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        counterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        counterLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        counterLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8).isActive = true
        counterLabel.heightAnchor.constraint(equalTo: counterLabel.widthAnchor, multiplier: 0.8).isActive = true
    }
    
    // Tier 6 - Flip camera button contraints
    func flipCameraButtonConstraints() {
        flipCameraButton.translatesAutoresizingMaskIntoConstraints = false
        flipCameraButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: view.frame.width*0.05).isActive = true
        flipCameraButton.centerYAnchor.constraint(equalTo: classifierLabel.centerYAnchor).isActive = true
        flipCameraButton.heightAnchor.constraint(equalTo: classifierLabel.heightAnchor).isActive = true
        flipCameraButton.widthAnchor.constraint(equalTo: highScoreLabel.heightAnchor).isActive = true
    }
    
    func setupView() {
        // Tier 0 - Setup camera session
        do {
            try setupAVSession()
        } catch {
            AppError.display(error, inViewController: self)
        }
        
        // Tier 0.5 - Vision views
        setupVisionViews()
        
        // Tier 1 - Setup classifier label
        setupClassifierLabel()
        
        // Tier 2 - Setup highscore label
        setupHighScoreLabel()
        
        // Tier 3 - Setup Confidence label
        setupConficendeLabel()
        
        // Tier 4 - Setup best label
        setupBestLabel()
        
        // Tier 5 - Counter label
        setupCounterLabel()
        
        // Tier 6 - Flip camera button
        setupFlipCameraButton()
    }
}
