//
//  CourseColor.swift
//  ReCal iOS
//
//  Created by Naphat Sanguansin on 11/22/14.
//  Copyright (c) 2014 ReCal. All rights reserved.
//

import UIKit
import ReCalCommon

private let hashPrimeMultiplier = 131071

class CourseColor: NSObject, NSCoding, Hashable, NSCopying {
    private struct CodingKeys {
        static let NormalColor = "CourseColorNormalColor"
        static let HighlightedColor = "CourseColorHighlightedColor"
        static let ServerId = "ServerId"
    }
    let normalColorRepresentation: ColorRepresentation
    lazy var normalColor: UIColor = {
        return UIColor(colorRepresentation: self.normalColorRepresentation)
    }()
    let highlightedColorRepresentation: ColorRepresentation
    lazy var highlightedColor: UIColor = {
        return UIColor(colorRepresentation: self.highlightedColorRepresentation)
    }()
    let serverId: String
    init(normalColorHexString: String, highlightedColorHexString: String, serverId: String) {
        // TODO normalize hex string
        self.normalColorRepresentation = ColorRepresentation(hexString: normalColorHexString)
        self.highlightedColorRepresentation = ColorRepresentation(hexString: highlightedColorHexString)
        self.serverId = serverId
        super.init()
    }
    init(normalColorRepresentation: ColorRepresentation, highlightedColorRepresentation: ColorRepresentation, serverId: String) {
        self.normalColorRepresentation = normalColorRepresentation
        self.highlightedColorRepresentation = highlightedColorRepresentation
        self.serverId = serverId
        super.init()
    }
    required init(coder aDecoder: NSCoder) {
        self.serverId = aDecoder.decodeObjectForKey(CodingKeys.ServerId) as! String
        self.normalColorRepresentation = aDecoder.decodeObjectForKey(CodingKeys.NormalColor) as! ColorRepresentation
        self.highlightedColorRepresentation = aDecoder.decodeObjectForKey(CodingKeys.HighlightedColor) as! ColorRepresentation
    }
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.serverId, forKey: CodingKeys.ServerId)
        aCoder.encodeObject(self.normalColorRepresentation, forKey: CodingKeys.NormalColor)
        aCoder.encodeObject(self.highlightedColorRepresentation, forKey: CodingKeys.HighlightedColor)
    }
    override var hashValue: Int {
        return self.normalColorRepresentation.hashValue &* hashPrimeMultiplier &+ self.highlightedColorRepresentation.hashValue
    }
    override func isEqual(object: AnyObject?) -> Bool {
        if let color = object as? CourseColor {
            return color == self
        } else {
            return super.isEqual(object)
        }
    }
    func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = CourseColor(normalColorRepresentation: self.normalColorRepresentation.copyWithZone(zone) as! ColorRepresentation, highlightedColorRepresentation: self.highlightedColorRepresentation.copyWithZone(zone) as! ColorRepresentation,
            serverId: self.serverId)
        return copy
    }
}

func == (lhs: CourseColor, rhs: CourseColor) -> Bool {
    return lhs.highlightedColorRepresentation == rhs.highlightedColorRepresentation && lhs.normalColorRepresentation == rhs.normalColorRepresentation
}