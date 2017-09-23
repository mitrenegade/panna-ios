//
//  LoggingService.swift
//  Balizinha
//
//  Created by Bobby Ren on 9/10/17.
//  Copyright © 2017 Bobby Ren. All rights reserved.
//

import UIKit
import Firebase

fileprivate var singleton: LoggingService?
fileprivate var loggingRef: DatabaseReference?

class LoggingService: NSObject {
    private lazy var __once: () = {
        // firRef is the global firebase ref
        loggingRef = firRef.child("logs") // this creates a query on the endpoint /logs
    }()

    // MARK: - Singleton
    static var shared: LoggingService {
        if singleton == nil {
            singleton = LoggingService()
            singleton?.__once
        }
        
        return singleton!
    }

    func log(event: String, info: [AnyHashable: Any]?) {
        guard TESTING else { return }
        guard let ref = loggingRef?.child(event).childByAutoId() else { return }
        var params = info ?? [:]
        params["timestamp"] = Date().timeIntervalSince1970
        ref.updateChildValues(params)
    }
}