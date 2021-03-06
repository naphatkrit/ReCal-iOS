//
//  CollectionViewCalendarWeekLayout.swift
//  ReCal iOS
//
//  Created by Naphat Sanguansin on 10/15/14.
//  Copyright (c) 2014 ReCal. All rights reserved.
//

import UIKit

private let debug = false

private let gridLineWidth: CGFloat = 0.5
private let gridLineZIndex = 1
private let eventsZIndex = gridLineZIndex + 1
private let timeRowHeaderBackgroundZIndex = eventsZIndex + 1
private let timeRowHeaderZIndex = timeRowHeaderBackgroundZIndex + 1
private let dayColumnHeaderBackgroundZIndex = timeRowHeaderZIndex + 1
private let dayColumnHeaderZIndex = dayColumnHeaderBackgroundZIndex + 1


/// A subclass of UICollectionViewLayout that provides a week view-like interface. Each section shuold correspond to a day, and each item an event. Does not support multi-day events right now.
public class CollectionViewCalendarWeekLayout: UICollectionViewLayout {
    
    /// MARK: Properties
    public weak var dataSource: CollectionViewDataSourceCalendarWeekLayout?
    
    private let calendar: NSCalendar! = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
    
    private let eventCellPadding = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 3)
    
    public var daySectionWidth: CGFloat {
        var finalWidth: Float = 300.0 // TODO default value?
        if let sectionWidth = self.dataSource?.daySectionWidthForCollectionView(self.collectionView!, layout: self) {
            switch sectionWidth {
            case .Exact(let width):
                finalWidth = width
            case .VisibleNumberOfDays(let days):
                finalWidth = floor(Float(self.collectionView!.frame.size.width - self.timeRowHeaderWidth) / Float(days))
            }
        }
        return max(CGFloat(finalWidth), 0) // if collection view width is smaller than time row header width, then we could get a negative value
    }
    private var layoutHeight: CGFloat {
        var finalHeight: Float = 300.0 // TODO default value?
        if let layoutHeight = self.dataSource?.heightForCollectionView(self.collectionView!, layout: self) {
            switch layoutHeight {
            case .Exact(let height):
                finalHeight = height
            case .Fit:
                finalHeight = Float(self.collectionView!.frame.size.height)
            }
        }
        return CGFloat(finalHeight)
    }
    private var dayColumnHeaderHeight: CGFloat {
        var finalHeight: Float = 300.0 // TODO default value?
        if let height = self.dataSource?.dayColumnHeaderHeightForCollectionView(self.collectionView!, layout: self) {
            finalHeight = height
        }
        return CGFloat(finalHeight)
    }
    private var timeRowHeaderWidth: CGFloat {
        var finalWidth: CGFloat = 300.0
        if let width = self.dataSource?.timeRowHeaderWidthForCollectionView(self.collectionView!, layout: self) {
            finalWidth = CGFloat(width)
        }
        return finalWidth
    }
    private var hourSlotHeight: CGFloat {
        return floor((self.layoutHeight - self.dayColumnHeaderHeight) / CGFloat(self.maximumHour - self.minimumHour))
    }
    private var visibleDaySections: [Int] {
        let leftMargin = self.timeRowHeaderWidth
        let contentOffset = self.collectionView!.contentOffset
        let bounds = self.collectionView!.bounds
        let sectionWidth = self.daySectionWidth
        if sectionWidth == 0 {
            return []
        }
        let possibleMinSection = Int((contentOffset.x - leftMargin)/sectionWidth) // ok to cast down, we just want a section that's to the left of the left most visible section
        let sectionDelta = Int(ceil(bounds.width / sectionWidth))
        let possibleMaxSection = possibleMinSection + sectionDelta
        let minSection = max(possibleMinSection, 0)
        let maxSection = min(possibleMaxSection, self.collectionView!.numberOfSections() - 1)
        return (minSection...maxSection).map{ $0 }
    }
    private var minimumHour: Int {
        if let minimumHour = self.dataSource?.minimumHourForCollectionView(self.collectionView!, layout: self) {
            assert(minimumHour >= 0 && minimumHour <= 23, "The minimum hour must be between 0 and 23, inclusive") // autoclosure means we don't do this unless when debugging
            return minimumHour
        }
        return 0 // default value
    }
    private var maximumHour: Int {
        if let maximumHour = self.dataSource?.maximumHourForCollectionView(self.collectionView!, layout: self) {
            assert(maximumHour >= 1 && maximumHour <= 24, "The maximum hour must be between 1 and 24, inclusive")
            assert(maximumHour > self.minimumHour, "The maximum hour must be greater than the minimum hour")
            return maximumHour
        }
        return 24
    }
    private var hourStep: Float {
        if let hourStep = self.dataSource?.hourStepForCollectionView(self.collectionView!, layout: self) {
            assert(hourStep > 0.0, "The hour step must be positive")
            return hourStep
        }
        return 1.0
    }
    private var nearestVisibleSection: Int {
        let contentOffset = self.collectionView!.contentOffset
        return self.nearestSectionForContentOffset(contentOffset)
    }
    
    /// MARK: Caches
    private var eventsLayoutAttributesCache = Cache<NSIndexPath, UICollectionViewLayoutAttributes>()
    private var dayColumnHeaderBackgroundLayoutAttributesCache = Cache<NSIndexPath, UICollectionViewLayoutAttributes>()
    private var dayColumnHeaderLayoutAttributesCache = Cache<NSIndexPath, UICollectionViewLayoutAttributes>()
    private var timeRowHeaderBackgroundLayoutAttributesCache = Cache<NSIndexPath, UICollectionViewLayoutAttributes>()
    private var timeRowHeaderLayoutAttributesCache = Cache<NSIndexPath, UICollectionViewLayoutAttributes>()
    private var verticalGridLineLayoutAttributesCache = Cache<NSIndexPath, UICollectionViewLayoutAttributes>()
    private var horizontalGridLineLayoutAttributesCache = Cache<NSIndexPath, UICollectionViewLayoutAttributes>()
    private var shouldRecalculateEventsLayoutAttributes: Bool {
        return self.eventsLayoutAttributesCache.isEmpty
    }
    private var shouldRecalculateDayColumnHeaderBackgroundLayoutAttributes: Bool {
        return self.dayColumnHeaderBackgroundLayoutAttributesCache.isEmpty
    }
    private var shouldRecalculateDayColumnHeaderLayoutAttributes: Bool {
        return self.dayColumnHeaderLayoutAttributesCache.isEmpty
    }
    private var shouldRecalculateTimeRowHeaderBackgroundLayoutAttributes: Bool {
        return self.timeRowHeaderBackgroundLayoutAttributesCache.isEmpty
    }
    private var shouldRecalculateTimeRowHeaderLayoutAttributes: Bool {
        return self.timeRowHeaderLayoutAttributesCache.isEmpty
    }
    private var shouldRecalculateVerticalGridLineLayoutAttributes: Bool {
        return self.verticalGridLineLayoutAttributesCache.isEmpty
    }
    private var shouldRecalculateHorizontalGridLineLayoutAttributes: Bool {
        return self.horizontalGridLineLayoutAttributesCache.isEmpty
    }
    
    /// MARK: Methods
    public override init() {
        super.init()
        self.initialize()
    }
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initialize()
    }
    
    private func initialize() {
        self.eventsLayoutAttributesCache.itemConstructor = {(indexPath: NSIndexPath) in
            return UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
        }
        
        self.dayColumnHeaderBackgroundLayoutAttributesCache.itemConstructor = {(indexPath: NSIndexPath) in
            return UICollectionViewLayoutAttributes(forDecorationViewOfKind: CollectionViewCalendarWeekLayoutDecorationViewKind.DayColumnHeaderBackground.rawValue, withIndexPath: indexPath)
        }
        
        self.dayColumnHeaderLayoutAttributesCache.itemConstructor = {(indexPath: NSIndexPath) in
            return UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: CollectionViewCalendarWeekLayoutSupplementaryViewKind.DayColumnHeader.rawValue, withIndexPath: indexPath)
        }
        self.timeRowHeaderBackgroundLayoutAttributesCache.itemConstructor = {(indexPath: NSIndexPath) in
            return UICollectionViewLayoutAttributes(forDecorationViewOfKind: CollectionViewCalendarWeekLayoutDecorationViewKind.TimeRowHeaderBackground.rawValue, withIndexPath: indexPath)
        }
        self.timeRowHeaderLayoutAttributesCache.itemConstructor = {(indexPath: NSIndexPath) in
            return UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: CollectionViewCalendarWeekLayoutSupplementaryViewKind.TimeRowHeader.rawValue, withIndexPath: indexPath)
        }
        self.verticalGridLineLayoutAttributesCache.itemConstructor = {(indexPath: NSIndexPath) in
            return UICollectionViewLayoutAttributes(forDecorationViewOfKind: CollectionViewCalendarWeekLayoutDecorationViewKind.VerticalGridLine.rawValue, withIndexPath: indexPath)
        }
        self.horizontalGridLineLayoutAttributesCache.itemConstructor = {(indexPath: NSIndexPath) in
            return UICollectionViewLayoutAttributes(forDecorationViewOfKind: CollectionViewCalendarWeekLayoutDecorationViewKind.HorizontalGridLine.rawValue, withIndexPath: indexPath)
        }
        
        if debug {
            self.eventsLayoutAttributesCache.willClear = {(_) in println("invalidating events cache") }
            self.dayColumnHeaderBackgroundLayoutAttributesCache.willClear = {(_) in println("invalidating day header background")}
            self.dayColumnHeaderLayoutAttributesCache.willClear = {(_) in println("invalidating day column header") }
            self.timeRowHeaderBackgroundLayoutAttributesCache.willClear = {(_) in println("invalidating time row header background") }
            self.timeRowHeaderLayoutAttributesCache.willClear = {(_) in println("invalidating time row header") }
            self.verticalGridLineLayoutAttributesCache.willClear = {(_) in println("invalidating vertical grid lines") }
            self.horizontalGridLineLayoutAttributesCache.willClear = {(_) in println("invalidating horizontal grid line")}
        }
    }
    
    override public func prepareLayout() {
        if self.dataSource == nil {
            return // cannot do anything without datasource
        }
        self.calculateLayoutAttributes()
    }
    
    /// find the closest section to this content offset. Note that this is the collection view's content offset. the way to think of it is: what if there were no margins?
    private func nearestSectionForContentOffset(contentOffset: CGPoint) -> Int {
        return Int(round(contentOffset.x / self.daySectionWidth))
    }
    private func contentOffsetXForSection(section: Int) -> CGFloat {
        return self.minXForSection(section) - self.timeRowHeaderWidth
    }
    
    /// MARK: Layout Attributes Calculation
    private func minXForSection(section: Int)->CGFloat {
        return CGFloat(section) * self.daySectionWidth + self.timeRowHeaderWidth
    }
    
    private func offsetYForTime(time: NSDate)-> CGFloat {
        // get how many hours this is away from min 
        let topMargin = self.dayColumnHeaderHeight
        let component = self.calendar.components((NSCalendarUnit.CalendarUnitHour | NSCalendarUnit.CalendarUnitMinute), fromDate: time)
        let curHour: Float = Float(component.hour) + Float(component.minute)/60.0
        let deltaHour = curHour - Float(self.minimumHour)
        return (deltaHour <= 0.0 ? 0.0 : floor(CGFloat(deltaHour) * self.hourSlotHeight)) + topMargin
    }
    
    private func calculateLayoutAttributes()
    {
        if self.collectionView == nil {
            return // cannot do anything
        }
        let visibleSections = self.visibleDaySections
        if self.shouldRecalculateDayColumnHeaderBackgroundLayoutAttributes {
            self.calculateDayColumnHeaderBackgroundLayoutAttributes()
        }
        if self.shouldRecalculateDayColumnHeaderLayoutAttributes {
            for section in visibleSections {
                self.calculateDayColumnHeaderLayoutAttributesForSection(section)
            }
        }
        if self.shouldRecalculateTimeRowHeaderBackgroundLayoutAttributes {
            self.calculateTimeRowHeaderBackgroundLayoutAttributes()
        }
        if self.shouldRecalculateTimeRowHeaderLayoutAttributes {
            self.calculateTimeRowHeaderLayoutAttributes()
        }
        if self.shouldRecalculateVerticalGridLineLayoutAttributes {
            for section in visibleSections {
                self.calculateVerticalGridLineForSection(section)
            }
            let maxVisible = visibleSections.reduce(0) { max($0, $1) }
            self.calculateVerticalGridLineForSection(maxVisible + 1)
        }
        if self.shouldRecalculateHorizontalGridLineLayoutAttributes {
            self.calculateHorizontalGridLineLayoutAttributes()
        }
        if self.shouldRecalculateEventsLayoutAttributes {
            for section in visibleSections {
                self.calculateEventsLayoutAttributesForSection(section)
            }
        }
    }
    private func calculateEventsLayoutAttributesForSection(section: Int) {
        let itemsCount = self.collectionView!.numberOfItemsInSection(section)
        if itemsCount == 0 {
            return
        }
        let minSectionX = self.minXForSection(section)
        let sectionWidth = self.daySectionWidth
        let calculateFrameForItemAtIndexPath: (NSIndexPath)->CGRect? = {(indexPath) in
            let startDateOpt = self.dataSource?.collectionView(self.collectionView!, layout: self, startDateForItemAtIndexPath: indexPath)
            let endDateOpt = self.dataSource?.collectionView(self.collectionView!, layout: self, endDateForItemAtIndexPath: indexPath)
            if startDateOpt == nil || endDateOpt == nil {
                return nil
            }
            let startDate = startDateOpt!
            let endDate = endDateOpt!
            let minY = self.offsetYForTime(startDate)
            let maxY = self.offsetYForTime(endDate)
            
            let height = maxY - minY
            return CGRect(x: minSectionX + self.eventCellPadding.left, y: minY + self.eventCellPadding.top, width: sectionWidth - self.eventCellPadding.left - self.eventCellPadding.right, height: height - self.eventCellPadding.top - self.eventCellPadding.bottom)
        }
        var attributesStack = Stack<UICollectionViewLayoutAttributes>()
        for i in 0...itemsCount-1 {
            let indexPath = NSIndexPath(forItem: i, inSection: section)
            if let frame = calculateFrameForItemAtIndexPath(indexPath) {
                var eventsLayoutAttributes = self.eventsLayoutAttributesCache[indexPath]
                eventsLayoutAttributes.frame = frame
                eventsLayoutAttributes.zIndex = eventsZIndex
                attributesStack.push(eventsLayoutAttributes)
            }
        }
        self.adjustEventsLayoutAttributesForOverlap(attributesStack.toArray())
    }
    private func adjustEventsLayoutAttributesForOverlap(allAttributes: [UICollectionViewLayoutAttributes]) {
        var adjustedAttributesSet = Set<UICollectionViewLayoutAttributes>()
        let sectionWidth = self.daySectionWidth
        let adjustOverlap: [UICollectionViewLayoutAttributes]->Void = { (overlappingAttributes) in
            if overlappingAttributes.count == 0 {
                return
            }
            // TODO better algorithm
            let adjustedWidth = sectionWidth / CGFloat(overlappingAttributes.count) // OK, will not be 0
            for (index, attributes) in enumerate(overlappingAttributes) {
                var frame = attributes.frame
                frame.origin.x += CGFloat(index) * adjustedWidth
                frame.size.width = adjustedWidth - self.eventCellPadding.left - self.eventCellPadding.right
                attributes.frame = frame
            }
        }
        for attributes in allAttributes {
            if adjustedAttributesSet.contains(attributes) {
                // already adjusted
                continue
            }
            
            // find overlapping events not already adjusted
            let frame = attributes.frame
            let toBeAdjusted = allAttributes.filter { !adjustedAttributesSet.contains($0) && CGRectIntersectsRect(frame, $0.frame) } // this will include the event itself by default
            adjustOverlap(toBeAdjusted)
            for adjusted in toBeAdjusted {
                adjustedAttributesSet.insert(adjusted)
            }
        }
    }

    private func calculateDayColumnHeaderBackgroundLayoutAttributes() {
        var backgroundLayoutAttributes = self.dayColumnHeaderBackgroundLayoutAttributesCache[NSIndexPath(forItem: 0, inSection: 0)]
        
        backgroundLayoutAttributes.frame = CGRectMake(self.collectionView!.contentOffset.x, self.collectionView!.contentOffset.y, self.collectionView!.frame.size.width, self.dayColumnHeaderHeight)
        backgroundLayoutAttributes.zIndex = dayColumnHeaderBackgroundZIndex
    }
    private func calculateDayColumnHeaderLayoutAttributesForSection(section: Int) {
        let sectionMinX = self.minXForSection(section)
        let headerLayoutAttributes = self.dayColumnHeaderLayoutAttributesCache[NSIndexPath(index: section)]
        headerLayoutAttributes.frame = CGRectMake(sectionMinX, self.collectionView!.contentOffset.y, self.daySectionWidth, self.dayColumnHeaderHeight)
        headerLayoutAttributes.zIndex = dayColumnHeaderZIndex
    }
    
    private func calculateTimeRowHeaderBackgroundLayoutAttributes() {
        let timeBackgroundLayoutAttributes = self.timeRowHeaderBackgroundLayoutAttributesCache[NSIndexPath(forItem: 0, inSection: 0)]
        
        timeBackgroundLayoutAttributes.frame = CGRectMake(self.collectionView!.contentOffset.x, self.collectionView!.contentOffset.y, self.timeRowHeaderWidth, self.collectionView!.frame.size.height)
        timeBackgroundLayoutAttributes.zIndex = timeRowHeaderBackgroundZIndex
    }
    private func calculateTimeRowHeaderLayoutAttributes() {
        let minHour = Float(self.minimumHour)
        let maxHour = Float(self.maximumHour)
        let hourStep = self.hourStep
        let topMargin = self.dayColumnHeaderHeight
        let hourSlotHeight = self.hourSlotHeight
        let timeHeaderWidth = self.timeRowHeaderWidth
        let contentOffset = self.collectionView!.contentOffset
        var i = 0
        for var hour = minHour; hour < maxHour; hour += hourStep  {
            // this loops from minHour to maxHour, inclusive
            let timeLayoutAttributes = self.timeRowHeaderLayoutAttributesCache[NSIndexPath(index: i)]
            timeLayoutAttributes.frame = CGRectMake(contentOffset.x, CGFloat(hour - minHour) * hourSlotHeight + topMargin, timeHeaderWidth, 50.0) // TODO auto sizing cell
            timeLayoutAttributes.zIndex = timeRowHeaderZIndex
            i++
        }
    }
    
    private func calculateVerticalGridLineForSection(section: Int) {
        let sectionMinX = self.minXForSection(section)
        let verticalGridLineLayoutAttributes = self.verticalGridLineLayoutAttributesCache[NSIndexPath(index: section)]
        verticalGridLineLayoutAttributes.frame = CGRectMake(sectionMinX, self.collectionView!.contentOffset.y, gridLineWidth, self.collectionView!.bounds.size.height)
        verticalGridLineLayoutAttributes.zIndex = gridLineZIndex
    }
    private func calculateHorizontalGridLineLayoutAttributes() {
        let minHour = Float(self.minimumHour)
        let maxHour = Float(self.maximumHour)
        let hourStep = self.hourStep
        let topMargin = self.dayColumnHeaderHeight
        let hourSlotHeight = self.hourSlotHeight
        let timeHeaderWidth = self.timeRowHeaderWidth
        let contentOffset = self.collectionView!.contentOffset
        let bounds = self.collectionView!.bounds
        var i = 0
        for var hour = minHour; hour < maxHour; hour += hourStep {
            // this loops from minHour to maxHour, inclusive
            let timeLayoutAttributes = self.horizontalGridLineLayoutAttributesCache[NSIndexPath(index: i)]
            timeLayoutAttributes.frame = CGRectMake(contentOffset.x, CGFloat(hour - minHour) * hourSlotHeight + topMargin, bounds.size.width, gridLineWidth)
            timeLayoutAttributes.zIndex = gridLineZIndex
            i++
        }
    }
    
    /// MARK: Invalidation
    override public func invalidateLayoutWithContext(context: UICollectionViewLayoutInvalidationContext) {
        if debug {
            println("begin invalidation")
        }
        
        // invalidate efficiently
        let invalidateRowHeaders: ()->Void = {
            self.timeRowHeaderBackgroundLayoutAttributesCache.clearCache()
            self.timeRowHeaderLayoutAttributesCache.clearCache()
        }
        let invalidateColumnHeaders: ()->Void = {
            self.dayColumnHeaderBackgroundLayoutAttributesCache.clearCache()
            self.dayColumnHeaderLayoutAttributesCache.clearCache()
        }
        let invalidateGridLines: ()->Void = {
            self.verticalGridLineLayoutAttributesCache.clearCache()
            self.horizontalGridLineLayoutAttributesCache.clearCache()
        }
        let invalidateAll: ()->Void = {
            invalidateColumnHeaders()
            invalidateRowHeaders()
            invalidateGridLines()
            self.eventsLayoutAttributesCache.clearCache()
        }
        if context.invalidateEverything {
            invalidateAll()
        }
        if context.invalidateDataSourceCounts {
            invalidateAll()
        }
        if context.contentSizeAdjustment != CGSizeZero {
            invalidateAll()
            context.contentSizeAdjustment = CGSizeZero
        }
        if context.contentOffsetAdjustment != CGPointZero {
            invalidateAll()
            context.contentOffsetAdjustment = CGPointZero
        }
        // TODO specific items
        if debug {
            println("end invalidation")
            println("----------------------")
        }
        super.invalidateLayoutWithContext(context)
        
    }
    
    override public func invalidationContextForBoundsChange(newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        var context = super.invalidationContextForBoundsChange(newBounds)
        context.contentOffsetAdjustment = CGPointMake(newBounds.origin.x, newBounds.origin.y)
        context.contentSizeAdjustment = CGSizeMake(newBounds.size.width - self.collectionView!.bounds.size.width, newBounds.size.height - self.collectionView!.bounds.size.height)
        return context
    }
    override public func shouldInvalidateLayoutForPreferredLayoutAttributes(preferredAttributes: UICollectionViewLayoutAttributes, withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
        return false
    }
    /// MARK: UICollectionViewLayout Methods
    override public func collectionViewContentSize() -> CGSize {
        let numberOfSections: Int = self.collectionView!.numberOfSections()
        let finalWidth = self.daySectionWidth * CGFloat(numberOfSections) + self.timeRowHeaderWidth
        return CGSizeMake(finalWidth, self.layoutHeight)
    }
    
    override public func layoutAttributesForDecorationViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        if let kind = CollectionViewCalendarWeekLayoutDecorationViewKind(rawValue: elementKind) {
            switch kind {
            case .DayColumnHeaderBackground:
                return self.dayColumnHeaderBackgroundLayoutAttributesCache[indexPath]
            case .VerticalGridLine:
                return self.verticalGridLineLayoutAttributesCache[indexPath]
            case .TimeRowHeaderBackground:
                return self.timeRowHeaderBackgroundLayoutAttributesCache[indexPath]
            case .HorizontalGridLine:
                return self.horizontalGridLineLayoutAttributesCache[indexPath]
            }
        }
        assert(false, "Invalid Decoration View Kind \(elementKind)")
        return nil
    }
    
    override public func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return self.eventsLayoutAttributesCache[indexPath]
    }
    
    override public func layoutAttributesForSupplementaryViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        if let kind = CollectionViewCalendarWeekLayoutSupplementaryViewKind(rawValue: elementKind) {
            switch kind {
            case .DayColumnHeader:
                return self.dayColumnHeaderLayoutAttributesCache[indexPath]
            case .TimeRowHeader:
                
                return self.timeRowHeaderLayoutAttributesCache[indexPath]
            }
        }
        assert(false, "Invalid Supplementary View Kind \(elementKind)")
        return nil
    }
    
    override public func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        var visibleAttributes: [UICollectionViewLayoutAttributes] = []
        let visibleFilter:(NSIndexPath, UICollectionViewLayoutAttributes)->Bool = {(_, layoutAttributes) in
            return CGRectIntersectsRect(rect, layoutAttributes.frame)
        }
        // only need to filter elements that do not move when scrolling vertically. horizontal scrolling is automatically taken care of because we use the visible sections to create the layout, and that only changes with horizontal scrolling
        visibleAttributes += self.eventsLayoutAttributesCache.filter(visibleFilter)
        visibleAttributes += self.dayColumnHeaderBackgroundLayoutAttributesCache.values.array
        visibleAttributes += self.dayColumnHeaderLayoutAttributesCache.values.array
        visibleAttributes += self.verticalGridLineLayoutAttributesCache.values.array
        visibleAttributes += self.timeRowHeaderBackgroundLayoutAttributesCache.values.array
        visibleAttributes += self.timeRowHeaderLayoutAttributesCache.filter(visibleFilter)
        visibleAttributes += self.horizontalGridLineLayoutAttributesCache.filter(visibleFilter)
        return visibleAttributes
    }
    
    override public func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return true
    }

    override public func targetContentOffsetForProposedContentOffset(proposedContentOffset: CGPoint) -> CGPoint {
        let nearestSection = nearestSectionForContentOffset(proposedContentOffset)
        let newOffset = CGPoint(x: self.contentOffsetXForSection(nearestSection), y: proposedContentOffset.y)
        return newOffset
    }
    override public func targetContentOffsetForProposedContentOffset(proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        return self.targetContentOffsetForProposedContentOffset(proposedContentOffset)
    }
    
    // MARK: - Custom Methods
    public var firstVisibleSection: Int {
        return self.nearestSectionForContentOffset(self.collectionView!.contentOffset)
    }
    public func contentOffsetForSection(section: Int) -> CGPoint {
        return CGPoint(x: self.contentOffsetXForSection(section), y: self.collectionView?.contentOffset.y ?? 0)
    }
}
public enum CollectionViewCalendarWeekLayoutSupplementaryViewKind: String {
    case DayColumnHeader = "DayColumnHeader"
    case TimeRowHeader = "TimeRowHeader"
}
public enum CollectionViewCalendarWeekLayoutDecorationViewKind: String {
    case DayColumnHeaderBackground = "DayColumnHeaderBackground"
    case TimeRowHeaderBackground = "TimeRowHeaderBackground"
    case VerticalGridLine = "VerticalGridLine"
    case HorizontalGridLine = "HorizontalGridLine"
}