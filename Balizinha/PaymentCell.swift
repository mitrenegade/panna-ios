//
//  PaymentCell.swift
//  Balizinha
//
//  Created by Bobby Ren on 10/10/17.
//  Copyright © 2017 Bobby Ren. All rights reserved.
//

import UIKit
import FirebaseDatabase
import Stripe
import RxSwift
import Balizinha
import RenderPay
import RenderCloud
import RenderPay

class PaymentCell: UITableViewCell {

    var viewModel: PaymentViewModel?
    weak var paymentService: StripePaymentService!
    weak var hostController: UIViewController? {
        didSet {
            paymentService.loadPayment(hostController: hostController)
        }
    }

    fileprivate var disposeBag = DisposeBag()
    
    override func awakeFromNib() {
        paymentService = PannaServiceManager.stripePaymentService
        paymentService.statusObserver.distinctUntilChanged({$0 == $1}).subscribe(onNext: { [weak self] status in
            self?.viewModel = PaymentViewModel(status: status, privacy: true)
            self?.refreshPayment(status)
        }).disposed(by: disposeBag)
    }
    
    func refreshPayment(_ status: PaymentStatus) {
        guard let viewModel = viewModel else { return }
        guard let player = PlayerService.shared.current.value else { return }
        textLabel?.text = viewModel.labelTitle
        
        switch status {
        case .ready(let paymentSource):
            // always write card to firebase since it's an internal call
            print("Working payment source \(paymentSource)")
            
            // call savePaymentInfo only on change
            let sourceId = paymentSource.id
            if sourceId != paymentService.storedPaymentSource {
                paymentService.savePaymentInfo(userId: player.id, source: paymentSource.id, last4: paymentSource.last4 ?? "", label: paymentSource.label)
            }
        case .loading, .noCustomer, .noPaymentMethod, .needsRefresh:
            return
        }
    }
    
    func shouldShowPaymentController() {
        guard let viewModel = viewModel else { return }
        if viewModel.canAddPayment {
            LoggingService.shared.log(event: LoggingEvent.show_payment_controller, info: nil)
            paymentService.shouldShowPaymentController()
        } else if viewModel.needsValidateCustomer {
            LoggingService.shared.log(event: LoggingEvent.NeedsValidateCustomer, info: nil)
            if let player = PlayerService.shared.current.value, let email = player.email {
                paymentService.createCustomer(userId: player.id, email: email) { [weak self] (customerId, error) in
                    DispatchQueue.main.async {
                        self?.paymentService.loadPayment(hostController: self?.hostController)
                    }
                }
            }
        } else if viewModel.needsReplacePayment {
            LoggingService.shared.log(event: LoggingEvent.NeedsRefreshPayment, info: ["source": "PaymentCell"])
            hostController?.simpleAlert("Updated payment method needed", message: "Please delete your current card or account and replace your payment method.") { [weak self] in
                self?.paymentService.shouldShowPaymentController()
            }
        }
    }
}
