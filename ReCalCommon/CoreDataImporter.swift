//
//  CoreDataImporter.swift
//  ReCal iOS
//
//  Created by Naphat Sanguansin on 11/11/14.
//  Copyright (c) 2014 ReCal. All rights reserved.
//

import Foundation
import CoreData

public class CoreDataImporter {
    
    private var privateQueue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.name = "Core Data Importer"
        queue.qualityOfService = NSQualityOfService.Utility
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private func assertPrivateQueue() {
        assert(NSOperationQueue.currentQueue() == self.privateQueue)
    }
    private let temporaryDirectory = "core_data_importer_temp"
    
    private var temporaryDirectoryPath: String? {
        return NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).last?.stringByAppendingPathComponent(temporaryDirectory)
    }
    
    public var temporaryFileNames: [String] {
        return []
    }
    
    private var notificationObservers = [AnyObject]()
    private var timer: NSTimer!
    public let persistentStoreCoordinator: NSPersistentStoreCoordinator
    
    lazy public var backgroundManagedObjectContext: NSManagedObjectContext = {
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        return managedObjectContext
    }()
    
    public convenience init(persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        self.init(persistentStoreCoordinator: persistentStoreCoordinator, importInterval: 5)
    }
    public init(persistentStoreCoordinator: NSPersistentStoreCoordinator, importInterval: NSTimeInterval) {
        self.persistentStoreCoordinator = persistentStoreCoordinator
        self.timer = NSTimer.scheduledTimerWithTimeInterval(importInterval, target: self, selector: Selector("handleTimerInterrupt:"), userInfo: nil, repeats: true)
        
        let observer1 = NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil) { (notification) -> Void in
            self.backgroundManagedObjectContext.performBlockAndWait {
                self.backgroundManagedObjectContext.mergeChangesFromContextDidSaveNotification(notification)
            }
        }
        self.notificationObservers.append(observer1)
    }
    deinit {
        for observer in self.notificationObservers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
        self.timer.invalidate()
    }
    
    @objc public final func handleTimerInterrupt(_: NSTimer) {
        self.performBlock {
            let _ = self.importPendingItems()
        }
    }
    
    public final func writeJSONDataToPendingItemsDirectory(data: NSData, withTemporaryFileName fileName: String) {
        self.assertPrivateQueue()
        var errorOpt: NSError?
        let parsed: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.allZeros, error: &errorOpt)
        if let error = errorOpt {
            println("Error parsing json data. Aborting write. Error: \(error)")
            return
        }
        let parsedData = NSKeyedArchiver.archivedDataWithRootObject(parsed!)
        let fileManager = NSFileManager.defaultManager()
        if let temporaryDirectoryPath = self.temporaryDirectoryPath {
            if !fileManager.fileExistsAtPath(temporaryDirectoryPath) {
                fileManager.createDirectoryAtPath(temporaryDirectoryPath, withIntermediateDirectories: false, attributes: nil, error: &errorOpt)
                if let error = errorOpt {
                    println("Error creating temporary directory. Aborting. Error: \(error)")
                    return
                }
            }
            let temporaryFilePath = temporaryDirectoryPath.stringByAppendingPathComponent(fileName)
            if fileManager.fileExistsAtPath(temporaryFilePath) {
                fileManager.removeItemAtPath(temporaryFilePath, error: &errorOpt)
                if let error = errorOpt {
                    println("Error deleting old temporary file. Aborting save. Error: \(error)")
                    return
                }
            }
            fileManager.createFileAtPath(temporaryFilePath, contents: parsedData, attributes: nil)
        } else {
            println("Error getting directory path. Aborting save.")
        }
    }
    public final func importPendingItems() -> NSProgress {
        self.assertPrivateQueue()
        var progress = NSProgress(totalUnitCount: Int64(self.temporaryFileNames.count))
        // progress is now set
        
        for fileName in self.temporaryFileNames {
            progress.becomeCurrentWithPendingUnitCount(1)
            self.importPendingItems(temporaryFileName: fileName)
            progress.resignCurrent()
        }
        return progress
    }
    
    public func importPendingItems(#temporaryFileName: String)-> NSProgress {
        // ok to call this function many times. the second time, the file just wouldn't exist, which we handle
        self.assertPrivateQueue()
        let initialUnitCount: Int64 = 1
        var progress = NSProgress(totalUnitCount: initialUnitCount)
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), { () -> Void in
            self.performBlock {
                if let temporaryFilePath = self.temporaryDirectoryPath?.stringByAppendingPathComponent(temporaryFileName) {
                    let fileManager = NSFileManager.defaultManager()
                    if fileManager.fileExistsAtPath(temporaryFilePath) {
                        let dataOpt = NSData(contentsOfFile: temporaryFilePath)
                        var errorOpt: NSError?
                        if let data = dataOpt {
                            switch self.processData(data, fromTemporaryFileName: temporaryFileName, withProgress: progress) {
                            case .Success:
                                fileManager.removeItemAtPath(temporaryFilePath, error: &errorOpt)
                                if let error = errorOpt {
                                    println("Error deleting old temporary file. Aborting save. Error: \(error)")
                                }
                            case .ShouldRetry:
                                break // don't delete temp file. TODO change break to continue if this becomes a loop
                            case .Failure:
                                fileManager.removeItemAtPath(temporaryFilePath, error: &errorOpt)
                                if let error = errorOpt {
                                    println("Error deleting old temporary file. Aborting save. Error: \(error)")
                                }
                            }
                            NSNotificationCenter.defaultCenter().postNotificationName(Notifications.DidImport, object: self, userInfo: [NotificationUserInfo.ImportFileName: temporaryFileName])
                        }
                    } else {
                        // file does not exist
                        progress.completedUnitCount = initialUnitCount
                    }
                } else {
                    // could not get file path
                    progress.completedUnitCount = initialUnitCount
                }
            }
        })
        return progress
    }
    public func performBlock(closure: ()->Void) {
        self.privateQueue.addOperationWithBlock(closure)
    }
    public func performBlockAndWait(closure: ()->Void) {
        let operation = NSBlockOperation(block: closure)
        self.privateQueue.addOperation(operation)
        operation.waitUntilFinished()
    }
    public func processData(data: NSData, fromTemporaryFileName fileName: String, withProgress: NSProgress) -> ImportResult {
        return .Success
    }
    public enum ImportResult {
        /// Import successful. Delete temporary file
        case Success
        
        /// Recoverable error. Do not delete temporary file, so it will get imported on next import
        case ShouldRetry
        
        /// Unrecoverable error. Delete temporary file
        case Failure
    }
    public struct Notifications {
        public static let DidImport = "CoreDataImporterDidImport"
    }
    public struct NotificationUserInfo {
        public static let ImportFileName = "ImportFileName"
    }
}