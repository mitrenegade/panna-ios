//
//  MockService.swift
//  Panna
//
//  Created by Bobby Ren on 7/17/19.
//  Copyright © 2019 Bobby Ren. All rights reserved.
//

import UIKit
import Balizinha
import RenderCloud

class MockService: NSObject {
    static func mockLeague() -> League {
        return League(key: "abc", dict: ["name": "My league", "city": "Philadelphia", "info": "Airplane mode league", "ownerId": "1"])
    }

    static func mockPlayerOrganizer() -> Player {
        return Player(key: "1", dict: ["name":"Philly Phanatic", "city": "Philadelphia", "email": "test@gmail.com"])
    }

    static func mockPlayerMember() -> Player {
        return Player(key: "2", dict: ["name":"Gritty", "city": "Philadelphia", "email": "grittest@gmail.com"])
    }

    static func mockEventService() -> EventService {
        let dict: [String: Any] = ["name": "Test event",
                                        "status": "active",
                                        "startTime": (Date().timeIntervalSince1970 + 3600)] //Double(Int(arc4random_uniform(72)) * 3600))]
        let referenceSnapshot = MockDataSnapshot(exists: true,
                                                 key: "1",
                                                 value: dict,
                                                 ref: nil)
        let reference = MockDatabaseReference(snapshot: referenceSnapshot)
        let apiService = MockCloudAPIService(uniqueId: "abc", results: ["success": true])
        return EventService(apiService: apiService)
    }
    
    static func mockCityService() -> CityService {
        let dict: [String: Any] = ["name": "Boston",
                                        "lat": 75,
                                        "lon": -122]
        let referenceSnapshot = MockDataSnapshot(exists: true,
                                                 key: "123",
                                                 value: dict,
                                                 ref: nil)
        let reference = MockDatabaseReference(snapshot: referenceSnapshot)
        let apiService = MockCloudAPIService(uniqueId: "abc", results: ["success": true])
        return CityService(apiService: apiService)
    }
}
