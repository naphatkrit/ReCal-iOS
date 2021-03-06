//
//  EventsServerCommunication.swift
//  ReCal iOS
//
//  Created by Naphat Sanguansin on 11/16/14.
//  Copyright (c) 2014 ReCal. All rights reserved.
//

import Foundation
import ReCalCommon

class EventsServerCommunication : ServerCommunicator.ServerCommunication {
    
    override var request: NSURLRequest {
        let request = NSURLRequest(URL: NSURL(string: "\(Urls.eventsPullUrl)/0")!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 100)
        return request
    }
    
    override var idleInterval: Int {
        return 10
    }
    
    init(){
        super.init(identifier: "events")
    }
    
    override func handleCommunicationResult(result: ServerCommunicator.Result) -> ServerCommunicator.CompleteAction {
        switch result {
        case .Success(_, let data):
            println("Successfully downloaded event data")
            Settings.currentSettings.coreDataImporter.performBlockAndWait {
                let _ = Settings.currentSettings.coreDataImporter.writeJSONDataToPendingItemsDirectory(data, withTemporaryFileName: CalendarCoreDataImporter.TemporaryFileNames.events)
            }
            return .NoAction
        case .Failure(let error):
            println("Error downloading event data. Error: \(error)")
            return .NoAction
        }
    }
    override func shouldSendRequest() -> ServerCommunicator.ShouldSend {
        switch Settings.currentSettings.authenticator.state {
        case .Authenticated(_):
            return .Send
        case .Unauthenticated, .PreviouslyAuthenticated(_):
            return .NextInterrupt
        case .Cached(_):
            Settings.currentSettings.authenticator.authenticate()
            return .NextInterrupt
        case .Demo(_):
            return .Cancel
        }
    }
}