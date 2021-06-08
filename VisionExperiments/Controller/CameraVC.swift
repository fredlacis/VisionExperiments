//
//  CameraVC.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 05/06/21.
//

import UIKit
import Vision
import AVFoundation

// MARK: - Output Video Processor Delegate
protocol CameraOutputDelegate: AnyObject {
    func cameraOutput(_ controller: CameraVC, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation)
}

// MARK: - Session Methods Delegate
protocol CameraSessionDelegate: AnyObject {
    func makePrediction()
    func flipped(to: AVCaptureDevice.Position)
}

// MARK: - Camera View Controller Properties
class CameraVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Camera thread
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInitiated,
                                                     attributes: [], autoreleaseFrequency: .workItem)
    
    /// Camera output delegate
    weak var outputDelegate: CameraOutputDelegate?
    
    /// Camera session delegate
    weak var cameraSessionDelegate: CameraSessionDelegate?
    
    /// A view that exibits the body joints
    private let jointSegmentView = JointSegmentView()
    
    /// A view that exibits the body bounding box
    private let playerBoundingBox = BoundingBoxView()
    
    /// Camera postion | front/badk
    var cameraPosition: AVCaptureDevice.Position = .back
    
    /// Live camera feed management
    private var cameraFeedView: CameraFeedView!
    private var cameraFeedSession: AVCaptureSession?
    
    /// Perdictor
    let predictor: Predictor
    
    init(currentModel: MLModels) {
        self.predictor = Predictor(currentModel: currentModel)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Camera Session Setup
extension CameraVC {
    
    func setupAVSession() throws {
        /// Create device discovery session for a wide angle camera
        let wideAngle = AVCaptureDevice.DeviceType.builtInWideAngleCamera
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [wideAngle], mediaType: .video, position: cameraPosition)
        
        /// Select a video device, make an input
        guard let videoDevice = discoverySession.devices.first else {
            throw AppError.captureSessionSetup(reason: "Could not find a wide angle camera device.")
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        /// We prefer a 1080p video capture but if camera cannot provide it then fall back to highest possible quality
        if videoDevice.supportsSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }
        
        /// Add a video input
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            /// Add a video data output
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
        
        /// Always process the frames
        captureConnection?.isEnabled = true
        session.commitConfiguration()
        cameraFeedSession = session
        
        /// Get the interface orientaion from window scene to set proper video orientation on capture connection.
        let videoOrientation: AVCaptureVideoOrientation
        switch view.window?.windowScene?.interfaceOrientation {
        case .landscapeRight:
            videoOrientation = .landscapeRight
//        case .landscapeLeft:
//            videoOrientation = .landscapeLeft
        default:
            videoOrientation = .portrait
        }
        
        /// Create and setup video feed view
        cameraFeedView = CameraFeedView(frame: view.bounds, session: session, videoOrientation: videoOrientation)
        
        /// Starts running camera
        cameraFeedSession?.startRunning()
    }
}

// MARK: - Vision Methods
extension CameraVC {
    
    /// Gets joints from observed pose
    func getBodyJointsFor(observation: VNHumanBodyPoseObservation) -> ([VNHumanBodyPoseObservation.JointName: CGPoint]) {
        var joints = [VNHumanBodyPoseObservation.JointName: CGPoint]()
        guard let identifiedPoints = try? observation.recognizedPoints(.all) else {
            return joints
        }
        for (key, point) in identifiedPoints {
            guard point.confidence > 0.1 else { continue }
            if jointsOfInterest.contains(key) {
                joints[key] = point.location
            }
        }
        return joints
    }
    
    
    /// Bounding box
    func updateBoundingBox(_ boundingBox: BoundingBoxView, withRect rect: CGRect?) {
        /// Update the frame for player bounding box
        boundingBox.frame = rect ?? .zero
        boundingBox.perform(transition: (rect == nil ? .fadeOut : .fadeIn), duration: 0.1)
    }
    
    
    /// Human bounding box
    func humanBoundingBox(for observation: VNHumanBodyPoseObservation) -> CGRect {
        let bodyPoseDetectionMinConfidence: VNConfidence = 0.6
        let bodyPoseRecognizedPointMinConfidence: VNConfidence = 0.1
        
        var box = CGRect.zero
        var normalizedBoundingBox = CGRect.null
        /// Process body points only if the confidence is high.
        guard observation.confidence > bodyPoseDetectionMinConfidence, let points = try? observation.recognizedPoints(forGroupKey: .all) else {
            return box
        }
        /// Only use point if human pose joint was detected reliably.
        for (_, point) in points where point.confidence > bodyPoseRecognizedPointMinConfidence {
            normalizedBoundingBox = normalizedBoundingBox.union(CGRect(origin: point.location, size: .zero))
        }
        if !normalizedBoundingBox.isNull {
            box = normalizedBoundingBox
        }
        /// Fetch body joints from the observation and overlay them on the player.
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

// MARK: - Camera Output Live Video Processor
extension CameraVC {
    
    /// Predictes result from camera output
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        /// Delagete method
        outputDelegate?.cameraOutput(self, didReceiveBuffer: sampleBuffer, orientation: .up)
        
        /// Frame processor
        let detectPlayerRequest = predictor.processFrame(sampleBuffer)

        /// Updates visual references
        if let result = detectPlayerRequest.first {
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
        
        /// Request prediction
        cameraSessionDelegate?.makePrediction()
    }
}

// MARK: - Camera Methods
extension CameraVC {
    
    /// Updates Camera properties
    func updateCamera() {
        do {
            try setupAVSession()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }
    
    /// Flips camera
    @objc func flipCamera() {
        
        /// Update new position
        cameraPosition = cameraPosition == .front ? .back : .front
        
        /// Send information to respective VC
        cameraSessionDelegate?.flipped(to: cameraPosition)
        
        /// Change MLModel analysis orientation
        setPredictorOrientation()
    }
    
    /// Updates MLModel analysis orientation
    func setPredictorOrientation() {
        
        /// Front camera corresponds to left mirrored orientation
        if cameraPosition == .front {
            predictor.orientation = .leftMirrored
        }
        /// Back camera corresponds to right orientation
        else {
            predictor.orientation = .right
        }
    }
}

// MARK: - Camera UI
extension CameraVC {
    
    /// Tier 0 - Setup camera feed view UI
    func setupCameraFeedView() {
        view.addSubview(cameraFeedView)
        cameraFeedViewConstraints()
        cameraFeedView.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
    }
    
    /// Tier 1 - Setup Joint Segment View
    func setupVisionViews() {
        playerBoundingBox.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        playerBoundingBox.backgroundOpacity = 0
        playerBoundingBox.isHidden = false
        view.addSubview(playerBoundingBox)
        view.addSubview(jointSegmentView)
    }
    
    /// Tier 0 - Video output view constraints
    func cameraFeedViewConstraints() {
        cameraFeedView.translatesAutoresizingMaskIntoConstraints = false
        cameraFeedView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        cameraFeedView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        cameraFeedView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        cameraFeedView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    /// Setup camera subviews
    func setupCameraSubviews() {
        updateCamera()
        setupCameraFeedView()
        setupVisionViews()
    }
}
