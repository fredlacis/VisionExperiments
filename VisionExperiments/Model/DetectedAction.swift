//
//  DetectedAction.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 05/05/21.
//

import Foundation

// MARK: - Possible Actions to Detect With Respective Confidence
enum Actions: String {
    case juggling = "Juggling"
    case other = "Other"
}

struct DetectedAction {
    let action: Actions
    let confidence: Double
}
