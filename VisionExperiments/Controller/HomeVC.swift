//
//  HomeVC.swift
//  VisionExperiments
//
//  Created by Diogo Infante on 08/06/21.
//
import UIKit
import Foundation


class HomeVC: UIViewController {

    /// Logo image
    let logoImage = UIImageView()
    
    /// Juggling button
    let jugglingButton = SelectionButton(mlModel: .juggling)
    
    /// Crossbar button
    let crossbarButton = SelectionButton(mlModel: .juggling)

    /// Tagline label
    let taglineLabel = UILabel()
    
    /// Space
    let space = UIScreen.main.bounds.height*0.1
    
    override func viewDidLoad() {
        view.backgroundColor = .black
        setupSubviews()
    }
    

    
// MARK: - View Setup
    
    /// Tier 1 - Logo image
    func setupLogoImage() {
        view.addSubview(logoImage)
        logoImage.addImage(name: "logo")
        logoImageConstraints()
    }
    /// Tier 2 - Juggling Button
    func setupJugglingButton() {
        view.addSubview(jugglingButton)
        jugglingButton.addTarget(self, action: #selector(actionChoice(sender:)), for: .touchUpInside)
        jugglingButton.setTitle("Juggling Challenge", for: .normal)
        jugglingButton.titleLabel?.setHelveticaBold(fontSize: 20)
        jugglingButtonConstraints()
    }
    
    /// Tier 3 - Crossbar Button
    func setupCrossbarButton() {
        view.addSubview(crossbarButton)
        crossbarButton.titleLabel?.lineBreakMode = .byCharWrapping
        crossbarButton.setTitle("Crossbar Challenge\n(Coming Soon)", for: .normal)
        crossbarButton.titleLabel?.setHelveticaBold(fontSize: 20)
        crossbarButton.titleLabel?.textAlignment = .center
        crossbarButtonConstraints()
    }
    
    /// Tier 4 - Tagline label
    func setupTaglineLabel() {
        view.addSubview(taglineLabel)
        taglineLabel.text = "Time To Play Real"
        taglineLabel.textAlignment = .center
        taglineLabel.setHelveticaBold(fontSize: 30)
        taglineLabel.textColor = .orange
        taglineLabelConstraints()
    }
    
    /// Setup all subviews
    func setupSubviews() {
        setupLogoImage()
        setupJugglingButton()
        setupCrossbarButton()
        setupTaglineLabel()
    }
    
// MARK: - Constraint Setup
    
    /// Tier 1 - Logo image
    func logoImageConstraints() {
        logoImage.translatesAutoresizingMaskIntoConstraints = false
        logoImage.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        logoImage.topAnchor.constraint(equalTo: view.topAnchor, constant: space).isActive = true
        logoImage.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6).isActive = true
        logoImage.heightAnchor.constraint(equalTo: logoImage.widthAnchor).isActive = true
    }
    /// Tier 2 - Juggling button
    func jugglingButtonConstraints() {
        jugglingButton.translatesAutoresizingMaskIntoConstraints = false
        jugglingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        jugglingButton.topAnchor.constraint(equalTo: logoImage.bottomAnchor, constant: space).isActive = true
        jugglingButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6).isActive = true
        jugglingButton.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25).isActive = true
    }
    /// Tier 3 - Crossbar button
    func crossbarButtonConstraints() {
        crossbarButton.translatesAutoresizingMaskIntoConstraints = false
        crossbarButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        crossbarButton.topAnchor.constraint(equalTo: jugglingButton.bottomAnchor, constant: space/2).isActive = true
        crossbarButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6).isActive = true
        crossbarButton.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25).isActive = true
    }
    
    /// Tier 4 - Tagline label
    func taglineLabelConstraints() {
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        taglineLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        taglineLabel.topAnchor.constraint(equalTo: crossbarButton.bottomAnchor).isActive = true
        taglineLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        taglineLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8).isActive = true
    }
    
// MARK: - Methods
    
    /// Presents next view controller accordind to choosen challenge
    @objc func actionChoice(sender: SelectionButton) {
        self.presentFullScreen(JugglingVC(currentModel: .juggling))
    }
}
