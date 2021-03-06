//
//  AuthenticationNavigationController.swift
//  ReCal iOS
//
//  Created by Naphat Sanguansin on 11/9/14.
//  Copyright (c) 2014 ReCal. All rights reserved.
//

import UIKit

private let authenticationPromptViewControllerStoryboardId = "AuthenticationPrompt"

public class AuthenticationNavigationController: UINavigationController {

    public var logicalRootViewController: UIViewController!
    public let authenticationPromptViewController: AuthenticationPromptViewController
    private var notificationObservers: [AnyObject] = []
    
    override init(rootViewController: UIViewController) {
        self.logicalRootViewController = rootViewController
        self.authenticationPromptViewController = UIStoryboard(name: "ReCalCommon", bundle: NSBundle(identifier: "io.recal.ReCalCommon")).instantiateViewControllerWithIdentifier(authenticationPromptViewControllerStoryboardId) as! AuthenticationPromptViewController
        super.init(rootViewController: self.authenticationPromptViewController)
    }

    required public init(coder aDecoder: NSCoder) {
        self.authenticationPromptViewController = UIStoryboard(name: "ReCalCommon", bundle: NSBundle(identifier: "io.recal.ReCalCommon")).instantiateViewControllerWithIdentifier(authenticationPromptViewControllerStoryboardId) as! AuthenticationPromptViewController
        super.init(coder: aDecoder)
        self.logicalRootViewController = self.viewControllers.first as? UIViewController
        self.setViewControllers([self.authenticationPromptViewController], animated: false)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        let updateWithColorScheme:(ColorScheme)->Void = {(colorScheme) in
            self.view.tintColor = colorScheme.actionableTextColor
            switch Settings.currentSettings.theme {
            case .Light:
                self.navigationBar.barStyle = .Default
            case .Dark:
                self.navigationBar.barStyle = .Black
            }
        }
        updateWithColorScheme(Settings.currentSettings.colorScheme)
        
        switch Settings.currentSettings.authenticator.state {
        case .Unauthenticated:
            break
        case .Authenticated(_), .PreviouslyAuthenticated(_), .Cached(_), .Demo(_):
            self.setViewControllers([self.logicalRootViewController], animated: false)
        }
        
        let observer = NSNotificationCenter.defaultCenter().addObserverForName(authenticatorStateDidChangeNofication, object: nil, queue: NSOperationQueue.mainQueue()) { (_) -> Void in
            switch Settings.currentSettings.authenticator.state {
            case .Authenticated(_), .PreviouslyAuthenticated(_), .Cached(_), .Demo(_):
                if self.topViewController == self.authenticationPromptViewController {
                    self.setViewControllers([self.logicalRootViewController], animated: true)
                }
            case .Unauthenticated:
                if self.topViewController != self.authenticationPromptViewController {
                    self.setViewControllers([self.authenticationPromptViewController, self.topViewController], animated: false)
                    self.popToRootViewControllerAnimated(true)
                }
            }
        }
        let observer2 = NSNotificationCenter.defaultCenter().addObserverForName(Settings.Notifications.ThemeDidChange, object: nil, queue: NSOperationQueue.mainQueue()) { (_) -> Void in
            updateWithColorScheme(Settings.currentSettings.colorScheme)
        }
        self.notificationObservers.append(observer)
        self.notificationObservers.append(observer2)
    }
    public override func viewDidAppear(animated: Bool) {
        UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: UIStatusBarAnimation.Slide)
    }
    deinit {
        for observer in self.notificationObservers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
