//
//  DoubleSidebarViewController.swift
//  ReCal iOS
//
//  Created by Naphat Sanguansin on 10/31/14.
//  Copyright (c) 2014 ReCal. All rights reserved.
//

import UIKit

public class DoubleSidebarViewController: UIViewController, UIScrollViewDelegate {

    /// The padding between the sidebar and the space outside of the view (so for the left sidebar, it's the left padding)
    private var sidebarOuterPadding: CGFloat {
        return self.view.bounds.size.width
    }
    
    /// The padding between the sidebars and the primary view
    private let sidebarInnerPadding: CGFloat = 0.0
    
    /// The width of the sidebars
    private var sidebarWidth: CGFloat {
        get {
            return self.view.bounds.size.width / 5.0
        }
    }
    
    /// The scrollview containing the sidebars
    private var sidebarContainerScrollView: UIScrollView!
    
    /// The view containing the entire left sidebar view
    private var leftSidebarView: UIView!
    
    /// The view containing the entire right sidebar view
    private var rightSidebarView: UIView!
    
    /// The logical primary content view exposed to subclass. Add subviews here
    private(set) public var primaryContentView: UIView!
    
    /// The logical left sidebar content view exposed to subclass. Add subviews here
    private(set) public var leftSidebarContentView: UIView!
    
    /// The logical right sidebar content view exposed to subclass. Add subviews here
    private(set) public var rightSidebarContentView: UIView!
    
    /// The state of the sidebars
    private var sidebarState: DoubleSidebarState = .Unselected
    
    /// What the content offset should be for the current state
    private var calculatedContentOffset: CGPoint {
        return self.contentOffsetForDoubleSidebarState(self.sidebarState)
    }
    
    /// Calculate the content offset for the given state
    private func contentOffsetForDoubleSidebarState(state: DoubleSidebarState) -> CGPoint {
        var x: CGFloat
        switch state {
        case .Unselected:
            x = self.sidebarWidth/2.0
        case .LeftSidebarShown:
            x = 0
        case .RightSidebarShown:
            x = self.sidebarWidth
        }
        return CGPoint(x: x, y: 0)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        let contentView = UIView()
        contentView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.view.addSubview(contentView)
        self.primaryContentView = contentView
        self.view.addConstraints(NSLayoutConstraint.layoutConstraintsForChildView(contentView, inParentView: self.view, withInsets: UIEdgeInsetsZero))
        self.setUpSidebar()
    }
    
    private func setUpSidebar() {
        // sidebar view
        self.leftSidebarView = UIView()
        // TODO autoresizing mask?
        self.rightSidebarView = UIView()
        
        // sidebar content view
        self.leftSidebarContentView = UIView()
        self.leftSidebarContentView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.rightSidebarContentView = UIView()
        self.rightSidebarContentView.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.leftSidebarView.addSubview(self.leftSidebarContentView)
        self.rightSidebarView.addSubview(self.rightSidebarContentView)
        
        // constraints
        self.leftSidebarView.addConstraints(NSLayoutConstraint.layoutConstraintsForChildView(self.leftSidebarContentView, inParentView: self.leftSidebarView, withInsets: UIEdgeInsets(top: 0, left: self.sidebarOuterPadding, bottom: 0, right: self.sidebarInnerPadding)))
        
        self.rightSidebarView.addConstraints(NSLayoutConstraint.layoutConstraintsForChildView(self.rightSidebarContentView, inParentView: self.rightSidebarView, withInsets: UIEdgeInsets(top: 0, left: self.sidebarInnerPadding, bottom: 0, right: self.sidebarOuterPadding)))
        
        self.setUpOverlayScrollView()
    }
    
    /// Set up the scroll view for sidebar
    private func setUpOverlayScrollView() {
        // creating and setting constraints
        let scrollView = OverlayScrollView()
        scrollView.delegate = self
        scrollView.setTranslatesAutoresizingMaskIntoConstraints(false)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        self.sidebarContainerScrollView = scrollView
        self.view.addSubview(scrollView)
        self.view.addConstraints(NSLayoutConstraint.layoutConstraintsForChildView(scrollView, inParentView: self.view, withInsets: UIEdgeInsetsZero))
        scrollView.contentSize = CGSize(width: self.sidebarWidth + self.view.bounds.size.width, height: self.view.bounds.size.height)
        self.view.addGestureRecognizer(scrollView.panGestureRecognizer)
        
        // adding sidebar
        scrollView.addSubview(self.leftSidebarView)
        self.leftSidebarView.frame = CGRect(x: -self.sidebarOuterPadding, y: 0, width: self.sidebarWidth + self.sidebarInnerPadding + self.sidebarOuterPadding, height: scrollView.contentSize.height)
        
        scrollView.addSubview(self.rightSidebarView)
        self.rightSidebarView.frame = CGRect(x: scrollView.contentSize.width - (self.sidebarWidth + self.sidebarInnerPadding), y: 0, width: self.sidebarWidth + self.sidebarInnerPadding + self.sidebarOuterPadding, height: scrollView.contentSize.height)
        
        scrollView.setContentOffset(self.calculatedContentOffset, animated: false)
        
        self.leftSidebarView.backgroundColor = UIColor.redColor()
        self.rightSidebarView.backgroundColor = UIColor.redColor()
    }
    
    public func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, var targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        switch self.sidebarState {
        case .Unselected:
            if velocity.x > 0 {
                // sidebar moving forward, meaning content moving to the left
                self.sidebarState = .RightSidebarShown
            } else if velocity.x < 0 {
                self.sidebarState = .LeftSidebarShown
            } else {
                // no velocity, tie break using target content offset
                if targetContentOffset.memory.x > self.calculatedContentOffset.x {
                    self.sidebarState = .RightSidebarShown
                } else if targetContentOffset.memory.x < self.calculatedContentOffset.x {
                    self.sidebarState = .LeftSidebarShown
                }
            }
        case .LeftSidebarShown:
            // the only way to go to the right sidebar state from here is if the content offset is already closer to that
            let unselectedContentOffset = self.contentOffsetForDoubleSidebarState(.Unselected)
            if scrollView.contentOffset.x > unselectedContentOffset.x {
                self.sidebarState = .RightSidebarShown
            } else {
                // otherwise, if the velocity is positive or if target content offset is greater than the current content offset, then set it to unselected
                if velocity.x > 0 || targetContentOffset.memory.x > self.calculatedContentOffset.x {
                    self.sidebarState = .Unselected
                }
            }
        case .RightSidebarShown:
            // reverse the logic of the left state
            // the only way to go to the right sidebar state from here is if the content offset is already closer to that
            let unselectedContentOffset = self.contentOffsetForDoubleSidebarState(.Unselected)
            if scrollView.contentOffset.x < unselectedContentOffset.x {
                self.sidebarState = .LeftSidebarShown
            } else {
                // otherwise, if the velocity is positive or if target content offset is greater than the current content offset, then set it to unselected
                if velocity.x < 0 || targetContentOffset.memory.x < self.calculatedContentOffset.x {
                    self.sidebarState = .Unselected
                }
            }
        }
        targetContentOffset.put(self.calculatedContentOffset)
    }
}

enum DoubleSidebarState {
    case Unselected, LeftSidebarShown, RightSidebarShown
}