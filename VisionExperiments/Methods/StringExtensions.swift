//
//  StringExtensions.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 30/04/21.
//

import Foundation

extension String {
    
    /// Gets the action with respective confidence from predtion string format
    func getAction()->DetectedAction {

        /// Case juggling
        if self.getLabel() == "Juggling" {
            return DetectedAction.juggling(Double(self.getConfidence()) ?? 0.0)
        }
        
        /// Case other
        return DetectedAction.other(Double(self.getConfidence()) ?? 0.0)
    }
    /// Gets label from CreateML prediction string format
    func getLabel()->String {
        
        let firstBlock = self.components(separatedBy: ":")
        
        let labelOnly = firstBlock[1].components(separatedBy: "|")
        
        return labelOnly[0].removeWhiteSpace()
    }
    
    /// Gets confidence percentage from CreateML prediction string format as string
    func getConfidence()->String {
        
        let confidenceBlock = self.components(separatedBy: ":")
        
        let confidenceOnly = confidenceBlock[2].removeWhiteSpace()
        
        guard var percentage = Double(confidenceOnly) else { return "0.0" }
        
        percentage *= 100
        
        let confidencePercentage = String(format: "%.2f", percentage)
        
        return confidencePercentage
    }
    
    /// Remove white space from string
    func removeWhiteSpace() -> String {
        
        let replaced = self.trimmingCharacters(in: NSCharacterSet.whitespaces)
        
        return replaced
    }
}
