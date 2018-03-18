//
//  StripeService.swift
//  Balizinha
//
//  Created by Bobby Ren on 9/21/17.
//  Copyright © 2017 Bobby Ren. All rights reserved.
//

import UIKit
import Stripe
import Firebase
import RxSwift

fileprivate var singleton: StripeService?

enum PaymentStatus {
    case loading
    case noCustomer // no customer_id exists
    case noPayment // customer_id exists, no payment
    case ready
}

class StripeService: NSObject {
    // payment method
    var paymentContext: STPPaymentContext?
    
    // paymentContext reactive based on hostController and customerId
    var hostController: UIViewController? {
        didSet {
            hostExists.value = hostController == nil ? false : true
        }
    }
    
    var hostExists: Variable<Bool> = Variable(false)
    var customerId: Variable<String> = Variable("")
    
    let status: Observable<PaymentStatus>

    override init() {
        self.status = Observable.combineLatest(hostExists.asObservable(), customerId.asObservable()) {exists, id in
            guard exists else { return .loading }
            guard !id.isEmpty else {
                return .loading
            }
            return .ready
        }
    }

    func loadPayment(host: UIViewController?) {
        guard let player = PlayerService.shared.current else {
            return
        }
        
        let ref = firRef.child("stripe_customers").child(player.id).child("customer_id")
        ref.observe(.value, with: { (snapshot) in
            guard snapshot.exists(), let customerId = snapshot.value as? String else {
                self.paymentContext = nil
                self.validateStripeCustomer(host: host)
                return
            }
            
            self.customerId.value = customerId
            // TODO: customer must exist or paymentContext is stuck in a loading state
            // but we shouldn't have to create a customer unless user has added a payment??
            // TODO: don't use paymentContext's loading for loading state of PaymentCell
            let customerContext = STPCustomerContext(keyProvider: self)
            self.paymentContext = STPPaymentContext(customerContext: customerContext)
            self.paymentContext?.delegate = self
            if let host = host {
                self.hostController = host
                self.paymentContext?.hostViewController = host
            } else if let host = self.hostController {
                self.paymentContext?.hostViewController = host
            }
        })
    }
    
    func createCharge(for event: Event, amount: Double, player: Player, isDonation: Bool = false, completion: ((_ success: Bool,_ error: Error?)->())?) {
        guard amount > 0 else {
            print("Invalid amount on event")
            completion?(false, NSError(domain: "balizinha", code: 0, userInfo: ["error": "Invalid amount on event", "eventId": event.id]))
            return
        }
        guard SettingsService.paymentRequired() || SettingsService.donation() else {
            // this error prevents rampant charges, but does present an error message to the user
            LoggingService.shared.log(event: LoggingEvent.FeatureFlagError, info: ["feature": "paymentRequired", "function": "createCharge"])
            completion?(false, NSError(domain: "balizinha", code: 0, userInfo: ["error": "Payment not allowed for Balizinha"]))
            return
        }
        let ref = firRef.child("charges/events").child(event.id).childByAutoId()
        let cents = ceil(amount * 100.0)
        var params:[AnyHashable: Any] = ["amount": cents, "player_id": player.id]
        if isDonation {
            params["isDonation"] = true
        }
        print("Creating charge for event \(event.id) for \(cents) cents")
        ref.updateChildValues(params)
        ref.observe(.value) { (snapshot: DataSnapshot) in
            guard snapshot.exists() else {
                // this can happen if we've created a charge object and deleted it. observer returns on the reference being deleted. shouldn'd delete the object, but in this situation just ignore.
                return
            }
            guard let info = snapshot.value as? [String: AnyObject] else {
                completion?(false,  NSError(domain: "stripe", code: 0, userInfo: ["error": "Could not save charge for eventId \(event.id) for player \(player.id)"]))
                return
            }
            if let status = info["status"] as? String, status == "succeeded" {
                print("status \(status)")
                completion?(true, nil)
            }
            else if let error = info["error"] as? String {
                completion?(false, NSError(domain: "stripe", code: 0, userInfo: ["error": error]))
            }
        }
    }
    
    func createSubscription(isTrial: Bool, completion: ((_ success: Bool,_ error: Error?)->())?) {
        guard let organizer = OrganizerService.shared.current else {
            completion?(false, NSError(domain: "balizinha", code: 0, userInfo: ["error": "Could not create subscription: no organizer"]))
            return
        }
        guard SettingsService.paymentRequired() || SettingsService.donation() else {
            // this error prevents rampant charges, but does present an error message to the user
            LoggingService.shared.log(event: LoggingEvent.FeatureFlagError, info: ["feature": "paymentRequired", "function": "createCharge"])
            completion?(false, NSError(domain: "balizinha", code: 0, userInfo: ["error": "Payment not allowed for Balizinha"]))
            return
        }
        let ref = firRef.child("charges/organizers").child(organizer.id).childByAutoId()
        print("Creating charge for organizer \(organizer.id)")
        
        // todo: set trial length here and send it into the cloud function?
        let params = ["subscription": true, "isTrial": isTrial]
        
        ref.updateChildValues(params)
        ref.observe(.value) { (snapshot: DataSnapshot) in
            guard snapshot.exists(), let info = snapshot.value as? [String: AnyObject] else {
                completion?(false,  NSError(domain: "stripe", code: 0, userInfo: ["error": "Could not save subscription for organizer \(organizer.id)"]))
                return
            }
            if let status = info["status"] as? String, status == "active" || status == "trialing"{
                print("status \(status)")
                completion?(true, nil)
            }
            else if let error = info["error"] as? String {
                let code: Int
                if error == "This customer has no attached payment source" {
                    code = 1001
                } else {
                    code = 1000
                }
                var userInfo: [String: Any] = ["error": error]
                if let deadline = info["deadline"] as? Double {
                    userInfo["deadline"] = deadline
                }
                completion?(false, NSError(domain: "stripe", code: code, userInfo: userInfo))
            }
        }
    }
    
    func validateStripeCustomer(host: UIViewController?) {
        // kicks off a process to create a new customer, then create a new payment context
        guard !self.customerId.value.isEmpty else { return }
        guard let player = PlayerService.shared.current, let email = player.email else { return } // TODO: handle error
        FirebaseAPIService().cloudFunction(functionName: "validateStripeCustomer", method: "POST", params: ["userId": player.id, "email": email], completion: { [weak self] (result, error) in
            // TODO: parse customer id and store it
            print("ValidateStripeCustomer result: \(result) error: \(error)")
            if let json = result as? [String: Any], let customer_id = json["customer_id"] as? String {
                self?.customerId.value = customer_id
            }
            if let host = host {
                self?.loadPayment(host: host)
            }
        })
    }
}

// MARK: - STPPaymentContextDelegate
extension StripeService: STPPaymentContextDelegate {
    func paymentContextDidChange(_ paymentContext: STPPaymentContext) {
        print("didChange. loading \(paymentContext.loading)")

        self.notify(NotificationType.PaymentContextChanged, object: nil, userInfo: nil)
    }
    
    func paymentContext(_ paymentContext: STPPaymentContext,
                        didCreatePaymentResult paymentResult: STPPaymentResult,
                        completion: @escaping STPErrorBlock) {
        print("didCreatePayment")
    }
    
    
    func paymentContext(_ paymentContext: STPPaymentContext, didFinishWith status: STPPaymentStatus, error: Error?) {
        print("didFinish")
        switch status {
        case .error: break
        //            self.showError(error)
        case .success: break
        //            self.showReceipt()
        case .userCancellation:
            return // Do nothing
        }
    }
    
    func paymentContext(_ paymentContext: STPPaymentContext,
                        didFailToLoadWithError error: Error) {
        print("didFailToLoad error \(error)")
        // Show the error to your user, etc.
    }
    
    
}

// MARK: - Customer Key
extension StripeService: STPEphemeralKeyProvider {
    func createCustomerKey(withAPIVersion apiVersion: String, completion: @escaping STPJSONResponseCompletionBlock) {
        let customerId = self.customerId.value
        guard !customerId.isEmpty else { return }
        let params: [String: Any] = ["api_version": apiVersion, "customer_id": customerId]
        let method = "POST"
        FirebaseAPIService().cloudFunction(functionName: "ephemeralKeys", method: method, params: params) { (result, error) in
            completion(result as? [AnyHashable: Any], error)
        }
    }
}
