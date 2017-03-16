//
//  SplashViewController.swift
//  Balizinha
//
//  Created by Bobby Ren on 1/19/17.
//  Copyright © 2017 Bobby Ren. All rights reserved.
//

import UIKit
import Parse
import FirebaseAuth

class SplashViewController: UIViewController {
    
    var handle: FIRAuthStateDidChangeListenerHandle?
    var loaded = false
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.handle = firAuth?.addStateDidChangeListener({ (auth, user) in
            if self.loaded {
                return
            }
            
            if let user = user {
                // user is logged in
                print("auth: \(auth) user: \(user) current \(firAuth?.currentUser)")
                self.goToMain()
                
                // pull user data from facebook
                // must be done after playerRef is created
                for provider in user.providerData {
                    if provider.providerID == "facebook.com" {
                        PlayerService.shared.createPlayer(name: user.displayName, email: user.email, city: nil, info: nil, photoUrl: user.photoURL?.absoluteString, completion: { (player, error) in
                            print("player \(player) error \(error)")
                        })
                    }
                }
            }
            else {
                self.goToSignupLogin()
            }
            
            if self.handle != nil {
                firAuth?.removeStateDidChangeListener(self.handle!)
                self.loaded = true
                self.handle = nil
            }
            
            // TODO: firebase does not remove user on deletion of app
        })

        listenFor(.LoginSuccess, action: #selector(didLogin), object: nil)
        listenFor(.LogoutSuccess, action: #selector(didLogout), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
    }
    
    deinit {
        stopListeningFor(.LoginSuccess)
        stopListeningFor(.LogoutSuccess)
    }
    
    func didLogin() {
        print("logged in")
        self.stopListeningFor(.LoginSuccess)
        self.goToMain()
    }
    
    func didLogout() {
        print("logged out")
        self.stopListeningFor(.LogoutSuccess)
        NotificationService.clearAllNotifications()
        
        self.goToSignupLogin()
    }
    
    private func goToMain() {
        guard let homeViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? UITabBarController else { return }
        homeViewController.selectedIndex = 1
        
        if let presented = presentedViewController {
            guard homeViewController != presented else { return }
            dismiss(animated: true, completion: {
                self.present(homeViewController, animated: true, completion: { 
                })
            })
        } else {
            self.present(homeViewController, animated: true, completion: {
            })
        }

        self.listenFor(NotificationType.LogoutSuccess, action: #selector(SplashViewController.didLogout), object: nil)
        EventService.shared.listenForEventUsers()
        PlayerService.shared.current // invoke listener
    }
    
    func goToSignupLogin() {
        guard let homeViewController = UIStoryboard(name: "LoginSignup", bundle: nil).instantiateInitialViewController() else { return }
        
        if let presented = presentedViewController {
            guard homeViewController != presented else { return }
            dismiss(animated: true, completion: {
                self.present(homeViewController, animated: true, completion: nil)
            })
        } else {
            present(homeViewController, animated: true, completion: nil)
        }
        
        self.listenFor(NotificationType.LoginSuccess, action: #selector(SplashViewController.didLogin), object: nil)
    }
    
}
