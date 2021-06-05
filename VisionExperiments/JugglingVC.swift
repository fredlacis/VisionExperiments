//
//  CameraViewController.swift
//  VisionExperiments
//
//  Created by Frederico Lacis de Carvalho on 29/04/21.
//

import UIKit
import AVFoundation
import Vision

class JugglingVC: CameraVC, CameraSessionDelegate {

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
    
    // Flip Camera Button
    let flipCameraButton = UIButton()
    
    // Counter
    private var count: Int = 0
    
    // High score
    private var highScore: Int = 0
    
    // Current confidence
    private var currentConfidence: Double = 0
    
    // The predictor for detecting human poses and tell if it's Juggling or not
//    let jugglin = JugglingPredictor()
    
    // Live camera feed management
    private var cameraFeedView: CameraFeedView!
    private var cameraFeedSession: AVCaptureSession?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Camera delegate
        cameraSessionDelegate = self
        
        // Setup subviews layout and constraints
        setupSubiews()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop capture session if it's running
        cameraFeedSession?.stopRunning()
    }
}

// MARK: - Methods
extension JugglingVC {
    
    // Camera flipped
    func flipped(to: AVCaptureDevice.Position) {
        setupSubiews()
    }
    
    // ML prediction
    func makePrediction() {
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
// MARK: - View Setup Extensions
extension JugglingVC {
    
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
    
    // Setup SubViews
    func setupSubiews() {
        
        // Tier 0 - Setup camera session
        setupCameraSubviews()

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

// MARK: - Constraint Setup Extensions
extension JugglingVC {
    
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
}
