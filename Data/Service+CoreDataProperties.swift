//
//  Service+CoreDataProperties.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/30/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//
//

import Foundation
import CoreData


extension Service {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Service> {
        return NSFetchRequest<Service>(entityName: "Service")
    }

    @NSManaged public var cost: NSDecimalNumber?
    @NSManaged public var date: Date?
    @NSManaged public var odometer: Int32
    @NSManaged public var vehicle: Car?
    @NSManaged public var vendor: Vendor?

}
