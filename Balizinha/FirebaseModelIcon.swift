//
//  FirebaseModelIcon.swift
//  Balizinha
//
//  Created by Bobby Ren on 4/21/18.
//  Copyright © 2018 Bobby Ren. All rights reserved.
//

import UIKit
import Balizinha

class FirebaseModelIcon: UIView {
    var imageView: RAImageView = RAImageView()
    var labelName: UILabel = UILabel()

    var object: FirebaseBaseModel? {
        didSet {
            refresh()
        }
    }
    
    internal func photoUrl(id: String?, completion: @escaping ((URL?)->Void)) {
        completion(nil)
    }
    
    internal var initials: String? {
        return nil
    }
    
    fileprivate func refreshPhoto() {
        imageView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = imageView.frame.size.height / 4
        imageView.contentMode = .scaleAspectFill
        
        labelName.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        labelName.clipsToBounds = true
        labelName.layer.cornerRadius = imageView.frame.size.height / 4
        labelName.font = UIFont.montserratSemiBold(size: frame.size.width / 2)
        
        labelName.textColor = UIColor.darkGreen
        labelName.layer.borderWidth = 1
        labelName.layer.borderColor = UIColor.darkGreen.cgColor
        labelName.textAlignment = .center

        photoUrl(id: object?.id) { [weak self] (url) in
            if let urlString = url?.absoluteString {
                self?.imageView.imageUrl = urlString
                self?.imageView.isHidden = false
                self?.labelName.isHidden = true
            } else if let strings = self?.initials {
                self?.labelName.text = strings
                self?.imageView.isHidden = true
                self?.labelName.isHidden = false
            } else {
                self?.imageView.imageUrl = nil
                self?.imageView.image = UIImage(named: "profile-img")
                self?.imageView.isHidden = false
                self?.labelName.isHidden = true
            }
        }
    }
    
    func refresh() {
        if labelName.superview == nil {
            self.addSubview(imageView)
        }
        if labelName.superview == nil {
            self.addSubview(labelName)
        }
        refreshPhoto()
    }
    
    func remove() {
        removeFromSuperview()
    }
}
