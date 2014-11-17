//
//  ScheduleCreationViewController.swift
//  ReCal iOS
//
//  Created by Naphat Sanguansin on 11/6/14.
//  Copyright (c) 2014 ReCal. All rights reserved.
//

import UIKit
import ReCalCommon

private let nameCellIdentifier = "NameCell"

class ScheduleCreationViewController: UITableViewController, UITextFieldDelegate {
    weak var delegate: ScheduleSelectionDelegate?

    private var nameTextField: UITextField? {
        return self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0))?.viewWithTag(1) as? UITextField
    }
    
    var managedObjectContext: NSManagedObjectContext!
    
    private var notificationObservers: [AnyObject] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let updateColorScheme: ()->Void = {
            self.tableView.backgroundColor = Settings.currentSettings.colorScheme.accessoryBackgroundColor
            self.tableView.reloadData()
        }
        updateColorScheme()
        let observer1 = NSNotificationCenter.defaultCenter().addObserverForName(Settings.Notifications.ThemeDidChange, object: nil, queue: NSOperationQueue.mainQueue()) { (_) -> Void in
            updateColorScheme()
        }
        self.notificationObservers.append(observer1)
    }
    
    deinit {
        for observer in self.notificationObservers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        self.nameTextField?.becomeFirstResponder()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func saveButtonTapped(sender: UIBarButtonItem) {
        if let name = self.nameTextField?.text? {
            // TODO remove hard coded term code
            var createdSchedule = Schedule(name: name, termCode: "1152")
            switch createdSchedule.commitToManagedObjectContext(self.managedObjectContext) {
            case .Success(let tempObjectId):
                var success = false
                var error: NSError?
                var schedule = self.managedObjectContext.objectWithID(tempObjectId) as CDSchedule
                self.managedObjectContext.performBlockAndWait {
                    success = self.managedObjectContext.save(&error)
                }
                if success {
                    self.delegate?.didSelectScheduleWithObjectId(schedule.objectID) // object id changes on save!
                } else {
                    println("error saving. error: \(error)")
                    assertionFailure("Failed to save schedule")
                }
            case .Failure:
                assertionFailure("Failed to save schedule")
                break
            }
        }
    }
    @IBAction func nameTextFieldValueChanged(sender: UITextField) {
        if sender.text == "" {
            self.navigationItem.rightBarButtonItem?.enabled = false
        } else {
            self.navigationItem.rightBarButtonItem?.enabled = true
        }
    }
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return 1
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Schedule Name"
        default:
            return nil
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(nameCellIdentifier, forIndexPath: indexPath) as UITableViewCell

        cell.textLabel.textColor = Settings.currentSettings.colorScheme.textColor
        cell.backgroundColor = Settings.currentSettings.colorScheme.contentBackgroundColor
        if let nameTextField = cell.viewWithTag(1) as? UITextField {
            nameTextField.textColor = Settings.currentSettings.colorScheme.textColor
            nameTextField.backgroundColor = Settings.currentSettings.colorScheme.contentBackgroundColor
            switch Settings.currentSettings.theme {
            case .Light:
                nameTextField.keyboardAppearance = .Light
            case .Dark:
                nameTextField.keyboardAppearance = .Dark
            }
        }
        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

}
