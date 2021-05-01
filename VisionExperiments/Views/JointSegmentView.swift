/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View that displays a joint segment.
*/

import UIKit
import Vision

class JointSegmentView: UIView, AnimatedTransitioning {
    
    // Joints dictionary composed by observed key and corelated point
    var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:] {
        didSet {
            updatePathLayer()
        }
    }

    // Joint point display parameters
    private let jointRadius: CGFloat = 3.0
    private let jointLayer = CAShapeLayer()
    private var jointPath = UIBezierPath()

    // Joints segments display parameters
    private let jointSegmentWidth: CGFloat = 2.0
    private let jointSegmentLayer = CAShapeLayer()
    private var jointSegmentPath = UIBezierPath()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    func resetView() {
        jointLayer.path = nil
        jointSegmentLayer.path = nil
    }

    // Setup layer parameters
    private func setupLayer() {
        jointSegmentLayer.lineCap = .round
        jointSegmentLayer.lineWidth = jointSegmentWidth
        jointSegmentLayer.fillColor = UIColor.clear.cgColor
        jointSegmentLayer.strokeColor = #colorLiteral(red: 0.6078431373, green: 0.9882352941, blue: 0, alpha: 1).cgColor
        layer.addSublayer(jointSegmentLayer)
        let jointColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1).cgColor
        jointLayer.strokeColor = jointColor
        jointLayer.fillColor = jointColor
        layer.addSublayer(jointLayer)
    }

    // Updates layer with current path information
    private func updatePathLayer() {
        
        // Coordinate transformation parameters
        let flipVertical = CGAffineTransform.verticalFlip
        let scaleToBounds = CGAffineTransform(scaleX: bounds.width, y: bounds.height)
        
        // Reset paths
        jointPath.removeAllPoints()
        jointSegmentPath.removeAllPoints()
        
        // Add all joints and segments
        for index in 0 ..< jointsOfInterest.count {
            if let nextJoint = joints[jointsOfInterest[index]] {
                
                /// There are basically two methods transform VNPoints Coordinates to main screen points
                
                /// 1 - Scale methods mannualy programed from Action Vision Sample Project
                let nextJointScaled = nextJoint.applying(flipVertical).applying(scaleToBounds)
                
                /// 2 - Internal vision conversion methods
//                let nextJointScaled = VNImagePointForNormalizedPoint(nextJoint, Int(bounds.width), Int(bounds.height))

                // Bezier path construction
                let nextJointPath = UIBezierPath(arcCenter: nextJointScaled, radius: jointRadius,
                                                 startAngle: CGFloat(0), endAngle: CGFloat.pi * 2, clockwise: true)
                jointPath.append(nextJointPath)
                
                // First point creation
                if jointSegmentPath.isEmpty {
                    jointSegmentPath.move(to: nextJointScaled)
                    dump(nextJointScaled)
                }
                
                // Following points
                else {
                    jointSegmentPath.addLine(to: nextJointScaled)
                    dump(nextJointScaled)
                }
            }
        }
        // Setting path to layer
        jointLayer.path = jointPath.cgPath
        jointSegmentLayer.path = jointSegmentPath.cgPath
    }
}
