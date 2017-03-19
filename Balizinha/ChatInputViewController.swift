//
//  ChatInputViewController.swift
//  Balizinha
//
//  Created by Bobby Ren on 3/8/17.
//  Copyright © 2017 Bobby Ren. All rights reserved.
//

import UIKit

class ChatInputViewController: UIViewController {
    @IBOutlet var inputText: UITextField!
    @IBOutlet var buttonSend: UIButton!
    
    var event: Event?
    
    @IBOutlet var constraintButtonWidth: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // setup keyboard accessories
        let keyboardDoneButtonView = UIToolbar()
        keyboardDoneButtonView.sizeToFit()
        keyboardDoneButtonView.barStyle = UIBarStyle.black
        keyboardDoneButtonView.tintColor = UIColor.white
        let sendBtn: UIBarButtonItem = UIBarButtonItem(title: "Send", style: UIBarButtonItemStyle.done, target: self, action: #selector(send))
        let clearBtn: UIBarButtonItem = UIBarButtonItem(title: "Clear", style: UIBarButtonItemStyle.done, target: self, action: #selector(clear))
        
        let flex: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        
        keyboardDoneButtonView.setItems([clearBtn, flex, sendBtn], animated: true)
        self.inputText.inputAccessoryView = keyboardDoneButtonView
    }
    
    @IBAction func didClickSend(_ sender: AnyObject?) {
        self.send()
    }
    
    func send() {
        print("sending text: \(self.inputText.text)")
        guard let text = self.inputText.text, text.characters.count > 0 else {
            self.clear()
            return
        }
        self.clear()
        
        guard let event = self.event else {
            return
        }
        let eventId = event.id
        
        ActionService.post(.chat, eventId: eventId, message: text)
    }
    
    func clear() {
        print("clear text")
        self.inputText.text = nil
        self.view.endEditing(true)
    }
    
    func toggleButton(show: Bool) {
        self.constraintButtonWidth.constant = show ? 46 : 0
    }
}