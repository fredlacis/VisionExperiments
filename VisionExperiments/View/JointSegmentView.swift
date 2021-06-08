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
    private let rightjointSegmentLayer = CAShapeLayer()
    private let leftjointSegmentLayer = CAShapeLayer()
    private var rightjointSegmentPath = UIBezierPath()
    private var leftjointSegmentPath = UIBezierPath()

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
        leftjointSegmentLayer.path = nil
        rightjointSegmentLayer.path = nil
    }

    // Setup layer parameters
    private func setupLayer() {
        leftjointSegmentLayer.lineCap = .round
        leftjointSegmentLayer.lineWidth = jointSegmentWidth
        leftjointSegmentLayer.fillColor = UIColor.clear.cgColor
        leftjointSegmentLayer.strokeColor = #colorLiteral(red: 0.6078431373, green: 0.9882352941, blue: 0, alpha: 1).cgColor
        layer.addSublayer(leftjointSegmentLayer)
        rightjointSegmentLayer.lineCap = .round
        rightjointSegmentLayer.lineWidth = jointSegmentWidth
        rightjointSegmentLayer.fillColor = UIColor.clear.cgColor
        rightjointSegmentLayer.strokeColor = #colorLiteral(red: 0.6078431373, green: 0.9882352941, blue: 0, alpha: 1).cgColor
        layer.addSublayer(rightjointSegmentLayer)
        let jointColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1).cgColor
        jointLayer.strokeColor = jointColor
        jointLayer.fillColor = jointColor
        layer.addSublayer(jointLayer)
    }

    // Updates layer with current path information
    private func updatePathLayer() {

        // Reset paths
        jointPath.removeAllPoints()
        leftjointSegmentPath.removeAllPoints()
        rightjointSegmentPath.removeAllPoints()
        
        updateLeftPathLayer()
        updateRightPathLayer()
        
        
        // Setting path to layer
        jointLayer.path = jointPath.cgPath
    }
    
    private func updateLeftPathLayer() {
        // Coordinate transformation parameters
        let flipVertical = CGAffineTransform.verticalFlip
        let scaleToBounds = CGAffineTransform(scaleX: bounds.width, y: bounds.height)
        
        // Add all joints and segments
        for index in 0 ..< leftJointsOfInterest.count {
            if let nextJoint = joints[leftJointsOfInterest[index]] {
                
                /// There are basically two methods transform VNPoints Coordinates to main screen points
                
                /// 1 - Scale methods mannualy programed from Action Vision Sample Project
                let nextJointScaled = nextJoint.applying(flipVertical).applying(scaleToBounds)
                
                /// 2 - Internal vision conversion methods
//                let nextJointScaled = VNImagePointForNormalizedPoint(nextJoint, Int(bounds.width), Int(bounds.height))

                // Bezier path construction
                let nextJointPath = UIBezierPath(arcCenter: nextJointScaled, radius: jointRadius,
                                                 startAngle: CGFloat(0), endAngle: CGFloat.pi * 2, clockwise: true)
                jointPath.append(nextJointPath)
                
                if leftjointSegmentPath.isEmpty {
                    // First point creation
                    leftjointSegmentPath.move(to: nextJointScaled)
//                    dump(nextJointScaled)
                } else {
                    // Following points
                    leftjointSegmentPath.addLine(to: nextJointScaled)
//                    dump(nextJointScaled)
                }
            }
        }
        
        leftjointSegmentLayer.path = leftjointSegmentPath.cgPath
    }
    
    private func updateRightPathLayer() {
        // Coordinate transformation parameters
        let flipVertical = CGAffineTransform.verticalFlip
        let scaleToBounds = CGAffineTransform(scaleX: bounds.width, y: bounds.height)
        
        // Add all joints and segments
        for index in 0 ..< rightJointsOfInterest.count {
            if let nextJoint = joints[rightJointsOfInterest[index]] {
                
                /// There are basically two methods transform VNPoints Coordinates to main screen points
                
                /// 1 - Scale methods mannualy programed from Action Vision Sample Project
                let nextJointScaled = nextJoint.applying(flipVertical).applying(scaleToBounds)
                
                /// 2 - Internal vision conversion methods
//                let nextJointScaled = VNImagePointForNormalizedPoint(nextJoint, Int(bounds.width), Int(bounds.height))

                // Bezier path construction
                let nextJointPath = UIBezierPath(arcCenter: nextJointScaled, radius: jointRadius,
                                                 startAngle: CGFloat(0), endAngle: CGFloat.pi * 2, clockwise: true)
                jointPath.append(nextJointPath)
                
                if rightjointSegmentPath.isEmpty {
                    // First point creation
                    rightjointSegmentPath.move(to: nextJointScaled)
//                    dump(nextJointScaled)
                } else {
                    // Following points
                    rightjointSegmentPath.addLine(to: nextJointScaled)
//                    dump(nextJointScaled)
                }
            }
        }
        
        rightjointSegmentLayer.path = rightjointSegmentPath.cgPath
    }
    
    private func joinBody() {
        
    }
}
