//
//  AppDelegate.swift
// Balizinha
//
//  Created by Bobby Ren on 5/8/16.
//  Copyright © 2016 Bobby Ren. All rights reserved.
//

import UIKit
import Firebase
import FBSDKCoreKit
import FBSDKLoginKit
import Batch
import Parse
import Fabric
import Crashlytics
import RxSwift
import Stripe

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let disposeBag = DisposeBag()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        //enable local notifications
        application.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))

        // Firebase
        // Do not include infolist in project: https://firebase.google.com/docs/configure/#reliable-analytics
        let plistFilename = "GoogleService-Info\(TESTING ? "-dev" : "")"
        let filePath = Bundle.main.path(forResource: plistFilename, ofType: "plist")
        assert(filePath != nil, "File doesn't exist")
        if let path = filePath, let fileopts = FirebaseOptions.init(contentsOfFile: path) {
            FirebaseApp.configure(options: fileopts)
        }
        Database.database().isPersistenceEnabled = true
        
        // Facebook
        FBSDKAppEvents.activateApp()
        FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // Parse
        let configuration = ParseClientConfiguration {
            $0.applicationId = PARSE_APP_ID
            $0.clientKey = PARSE_CLIENT_KEY
            $0.server = "https://lotsportz.herokuapp.com/parse"
        }
        Parse.initialize(with: configuration)
        
        // Crashlytics
        Fabric.sharedSDK().debug = true
        Fabric.with([Crashlytics.self])

        // Background fetch
        application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        
        logPlayerLogin()
        
        let STRIPE_KEY = TESTING ? STRIPE_KEY_DEV : STRIPE_KEY_PROD
        STPPaymentConfiguration.shared().publishableKey = STRIPE_KEY
        
        self.listenFor(NotificationType.LoginSuccess, action: #selector(logPlayerLogin), object: nil)

        let _ = SettingsService.shared

        return true
    }
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        print("local notification received: \(notification)")
        if let info = notification.userInfo {
            if let type = info["type"] as? String, type == "donationReminder", let eventId = info["eventId"] as? String {
                print("Go to donation for event \(eventId)")
                guard SettingsService.donation() else { return }
                self.notify(NotificationType.GoToDonationForEvent, object: nil, userInfo: ["eventId": eventId])
            }
        }
        else {
            let alert = UIAlertController(title: "Alert", message: "You have an event in one hour!", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            
            self.window?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return FBSDKApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
    }

    // Push
    // MARK: - Push
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Store the deviceToken in the current Installation and save it to Parse
        if #available(iOS 10.0, *) {
            NotificationService.registerForPushNotifications(deviceToken, enabled:true)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("failed: error \(error)")
        NotificationCenter.default.post(name: Notification.Name(rawValue: "push:enable:failed"), object: nil)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        print("notification received: \(userInfo)")
        /* format:
         [aps: {
         alert = "test push 2";
         sound = default;
         }]
         
         ]
         */
        guard let title = userInfo["title"] as? String else { return }
        guard let message = userInfo["message"] as? String else { return }
        guard let sender = userInfo["sender"] as? String, sender != firAuth.currentUser!.uid else {
            print("Own message, ignoring")
            return
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        
        self.window?.rootViewController?.present(alert, animated: true, completion: nil)
    }

}

// MARK: - Background fetch
extension AppDelegate {
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("PUSH: background fetch")
        LoggingService.shared.log(event: "BackgroundFetch", info: nil)
        completionHandler(UIBackgroundFetchResult.newData)
    }
}

extension AppDelegate {
    func logPlayerLogin() {
        // TODO: FIX THIS BEFORE RELEASE - try new devices
        // TODO: on logout/login, this doesn't get triggered again
        guard let observable = PlayerService.shared.observedPlayer else {
            print("doh")
            return
        }
        observable.take(1).subscribe(onNext: { (player) in
//            LoggingService.shared.log(event: "testWriteRemoteData", info: nil)
//            RemoteDataService.shared.post(userId: player.id, message: "testing")
            
            // checks for stripe customer
            StripeService().checkForStripeCustomer(player)
        }, onError: { (error) in
            print("error \(error)")
        }, onCompleted: { 
            print("completed")
        }, onDisposed: {
            print("disposed")
        }).addDisposableTo(disposeBag)
    }
}
