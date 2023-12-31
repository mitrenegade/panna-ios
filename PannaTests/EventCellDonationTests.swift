//
//  EventCellDonationTests.swift
//  Balizinha
//
//  Created by Bobby Ren on 10/9/17.
//  Copyright © 2017 Bobby Ren. All rights reserved.
//

import XCTest
import Balizinha
@testable import Panna

class EventCellDonationTests: XCTestCase {

    var viewModel: EventCellViewModel!
    var event: Balizinha.Event?
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        event = nil
        viewModel = nil
    }
    
    func testActionButtonForPastEvent() {
        setupPastEvent()
        guard let event = event else { return }
        XCTAssert(event.isPast == true, "Event should be past")

//        // past event, user owned
//        var status = (event.isPast, true, false)
//        XCTAssert(viewModel.buttonTitle(eventStatus: status) == "", "Past owned events should not show button")
//
//        // past event, user joined
//        status = (event.isPast, false, true)
//        XCTAssert(viewModel.buttonTitle(eventStatus: status) == "Pay", "Past joined events should show pay instead of donate")
//
//        // past event, user is not part of it
//        status = (event.isPast, false, false)
//        XCTAssert(viewModel.buttonTitle(eventStatus: status) == "", "Past events not joined should not show anything")
    }
    
    func testActionButtonForFutureEvent() {
        setupFutureEvent()
        guard let event = event else { return }
        XCTAssert(event.isPast == false, "Event should not be past")
        
        // future event, user owned
//        var status = (event.isPast, true, false)
//        XCTAssert(viewModel.buttonTitle(eventStatus: status) == "Edit", "Past owned events should not show button")
//        
//        // future event, user joined
//        status = (event.isPast, false, true)
//        XCTAssert(viewModel.buttonTitle(eventStatus: status) == "Leave", "Future joined event should show leave action")
//        
//        // future event, user is not part of it
//        status = (event.isPast, false, false)
//        XCTAssert(viewModel.buttonTitle(eventStatus: status) == "Join", "Future event should show join action")
    }
    
    fileprivate func setupPastEvent() {
        let hours = 5
        event = Balizinha.Event(key: "abc", dict: ["name": "PastEvent", "endTime": (Date().timeIntervalSince1970 - Double(hours * 3600)) as AnyObject])
        viewModel = EventCellViewModel(event: event!)
    }
    
    fileprivate func setupFutureEvent() {
        let hours = 5
        event = Balizinha.Event(key: "abc", dict: ["name": "FutureEvent", "endTime": (Date().timeIntervalSince1970 + Double(hours * 3600)) as AnyObject])
        viewModel = EventCellViewModel(event: event!)
    }
}
