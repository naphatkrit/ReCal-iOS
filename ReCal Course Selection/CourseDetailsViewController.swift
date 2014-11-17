//
//  CourseDetailsViewController.swift
//  ReCal iOS
//
//  Created by Naphat Sanguansin on 11/2/14.
//  Copyright (c) 2014 ReCal. All rights reserved.
//

import UIKit
import ReCalCommon

private let singleLabelCellReuseIdentifier = "SingleLabel"

class CourseDetailsViewController: UITableViewController {

    var course: Course? {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    private var notificationObservers: [AnyObject] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let updateColorScheme: ()->Void = {
            self.view.backgroundColor = Settings.currentSettings.colorScheme.accessoryBackgroundColor
        }
        updateColorScheme()
        let observer1 = NSNotificationCenter.defaultCenter().addObserverForName(Settings.Notifications.ThemeDidChange, object: nil, queue: NSOperationQueue.mainQueue()) { (_) -> Void in
            updateColorScheme()
            self.tableView.reloadData()
        }
        self.notificationObservers.append(observer1)
    }
    
    deinit {
        for observer in self.notificationObservers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    // MARK: - Table view data source
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return 1
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            let cell = tableView.dequeueReusableCellWithIdentifier(singleLabelCellReuseIdentifier, forIndexPath: indexPath) as UITableViewCell
            if let course = self.course {
                let label = cell.contentView.viewWithTag(1) as UILabel
                label.text = "\(course) - \(course.title)"
                label.textColor = Settings.currentSettings.colorScheme.textColor
            }
            cell.backgroundColor = Settings.currentSettings.colorScheme.contentBackgroundColor
            return cell
        case (1, 0):
            let cell = tableView.dequeueReusableCellWithIdentifier(singleLabelCellReuseIdentifier, forIndexPath: indexPath) as UITableViewCell
            if let course = self.course {
                let label = cell.contentView.viewWithTag(1) as UILabel
                label.font = UIFont.systemFontOfSize(UIFont.smallSystemFontSize())
                label.text = course.courseDescription
                label.textColor = Settings.currentSettings.colorScheme.textColor
            }
            cell.backgroundColor = Settings.currentSettings.colorScheme.contentBackgroundColor
            return cell
        default:
            assertionFailure("not implemented")
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        case 1:
            return "Description"
        default:
            assertionFailure("not implemented")
        }
    }
}
