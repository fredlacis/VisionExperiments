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
    
    // A view that exibits the body joints
    private let jointSegmentView = JointSegmentView()
    
    // A view that exibits the body bounding box
    private let playerBoundingBox = BoundingBoxView()
    
    // The predictor for detecting human poses and tell if it's Juggling or not
    let predictor = JugglingPredictor()
    
    // Live camera feed management
    private var cameraFeedView: CameraFeedView!
    private var cameraFeedSession: AVCaptureSession?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Tier 0 - Setup camera session
        do {
            try setupAVSession()
        } catch {
            AppError.display(error, inViewController: self)
        }
        
        // Tier 1 - Setup classifier label
        setupVisionViews()
        setupClassifierLabel()
        classifierLabelConstraints()
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
        
        // Prediction
        if predictor.isReadyToPredict {
            do {
                let prediction = try predictor.makePrediction()
                
                debugPrint(prediction)
                
                // Updates main theread UI
                DispatchQueue.main.async {
                    self.classifierLabel.text = "\(prediction.getLabel()) - \(prediction.getConfidence())%"
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
    //        if jointsOfInterest.contains(key) {
            print("Key: \(key), Location: \(point.location)")
                joints[key] = point.location
    //        }
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
        
        viewRect = cameraFeedView.viewRectConverted(fromNormalizedContentsRect: visionRect)
        
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
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [wideAngle], mediaType: .video, position: .unspecified)
        
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
    
    // Tier 1 - Setup Joint Segment View
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
        classifierLabel.layer.masksToBounds = true
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
        classifierLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -view.frame.height*0.3).isActive = true
        classifierLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5).isActive = true
        classifierLabel.heightAnchor.constraint(equalTo: classifierLabel.widthAnchor, multiplier: 0.25).isActive = true
    }
}
