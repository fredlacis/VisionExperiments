//
//  HomeVC.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 08/06/21.
//
import UIKit
import Foundation


class HomeVC: UIViewController {

    /// Juggling button
    let jugglingButton = SelectionButton(mlModel: .juggling)
    
    override func viewDidLoad() {
        setupSubviews()
    }
    

    
// MARK: - View Setup
    
    /// Tier 1 - Juggling Button
    func setupJugglingButton() {
        view.addSubview(jugglingButton)
        jugglingButton.addTarget(self, action: #selector(actionChoice(sender:)), for: .touchUpInside)
        jugglingButton.setTitle("Juggling Challenge", for: .normal)
        jugglingButton.titleLabel?.setHelveticaBold(fontSize: 20)
        jugglingButtonConstraints()
    }
    
    /// Setup all subviews
    func setupSubviews() {
        setupJugglingButton()
    }
    
// MARK: - Constraint Setup
    
    /// Tier 1 - Juggling Button
    func jugglingButtonConstraints() {
        jugglingButton.translatesAutoresizingMaskIntoConstraints = false
        jugglingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        jugglingButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        jugglingButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6).isActive = true
        jugglingButton.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.3).isActive = true
    }
    
// MARK: - Methods
    
    /// Presents next view controller accordind to choosen challenge
    @objc func actionChoice(sender: SelectionButton) {
        self.presentFullScreen(JugglingVC(currentModel: .juggling))
    }
}
