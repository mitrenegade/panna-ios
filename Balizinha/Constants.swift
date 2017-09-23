//
//  Constants.swift
// Balizinha
//
//  Created by Bobby Ren on 5/8/16.
//  Copyright © 2016 Bobby Ren. All rights reserved.
//

import UIKit
import Foundation
import Firebase

let leaveColor = UIColor(red: 253/256.0, green: 172/256.0, blue: 146/256.0, alpha: 1.0)
let joinColor = UIColor(red: 28/256.0, green: 71/256.0, blue: 131/256.0, alpha: 1.0)

var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

enum NotificationType: String {
    case LogoutSuccess
    case LoginSuccess
    case EventsChanged
    case PaymentContextChanged
    
    func name() -> Notification.Name {
        return Notification.Name(self.rawValue)
    }
}

var TESTING = true
var AIRPLANE_MODE = false

let STRIPE_KEY_DEV = "pk_test_YYNWvzYJi3bTyOJi2SNK3IkE"
let STRIPE_KEY_PROD = "pk_live_IziZ9EDk1374oI3rXjEciLBG"

var firRef = Database.database().reference()
let firAuth = Auth.auth()

let PARSE_APP_ID: String = "Y1kUP1Nwz77UlFW5wIGvK4ptgvCwKQjDejrXbMi7"
let PARSE_CLIENT_KEY: String = "NOTUSED-O7G1syjw0PXZTOmV0FTvsH9TSTvk7e7Ll6qpDWfW"

