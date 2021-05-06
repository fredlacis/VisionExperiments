//
//  DetectedAction.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 05/05/21.
//

import Foundation

// MARK: - Possible Actions to Detect With Respective Confidence
enum DetectedAction {
    case juggling(Double)
    case other(Double)
}
