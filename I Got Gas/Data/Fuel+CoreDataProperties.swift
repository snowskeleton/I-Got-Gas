//
//  Fuel+CoreDataProperties.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/30/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//
//

import Foundation
import CoreData


extension Fuel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Fuel> {
        return NSFetchRequest<Fuel>(entityName: "Fuel")
    }

    @NSManaged public var numberOfGallons: NSDecimalNumber?
    @NSManaged public var totalPrice: NSDecimalNumber?

}
