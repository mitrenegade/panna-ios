//
//  DeepLinkService.swift
//  Balizinha
//
//  Created by Bobby Ren on 12/21/17.
//  Copyright © 2017 Bobby Ren. All rights reserved.
//
// https://medium.com/@stasost/ios-how-to-open-deep-links-notifications-and-shortcuts-253fb38e1696
import UIKit

enum DeeplinkType {
    enum Messages {
        case root
        case details(String)
    }
    case messages(Messages)
    case event(String)
    
    // Event links shared should look like: balizinha://event/1
}

class DeepLinkService: NSObject {
    static let shared = DeepLinkService()

    override fileprivate init() {}
    private var deeplinkType: DeeplinkType?
    
    // opens any cached deeplinks on app startup
    func checkDeepLink() {
        guard let type = deeplinkType else { return }
        proceedToDeeplink(type)
        
        deeplinkType = nil
    }

    // handles deeplinks sent through a click
    func handle(url: URL) -> Bool{
        deeplinkType = parseDeepLink(url)
        guard let type = deeplinkType else { return false }
        proceedToDeeplink(type)
        return true
    }
    
    fileprivate func parseDeepLink(_ url: URL) -> DeeplinkType? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true), let host = components.host else {
            return nil
        }
        var pathComponents = components.path.components(separatedBy: "/")
        // the first component is empty
        pathComponents.removeFirst()
        switch host {
        case "messages":
            if let messageId = pathComponents.first {
                return DeeplinkType.messages(.details(messageId))
            }
        case "events":
            if let eventId = pathComponents.first {
                return DeeplinkType.event(eventId)
            }
        default:
            break
        }
        return nil
    }
    
    fileprivate func proceedToDeeplink(_ type: DeeplinkType) {
        switch type {
        case .messages(.root):
            print("Todo: show Messages Root")
        case .messages(.details(let id)):
            print("Todo: show Messages Details \(id)")
        case .event(let id):
            loadAndShowEvent(id)
        }
    }
    
    func loadAndShowEvent(_ eventId: String) {
        EventService.shared.featuredEventId = eventId
        self.notify(NotificationType.GoToMapForSharedEvent, object: nil, userInfo: nil)
        LoggingService.shared.log(event: LoggingEvent.DeepLinkForSharedEventOpened, info: nil)
    }
}