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

    @NSManaged public var cost: Double
    @NSManaged public var date: Date?
    @NSManaged public var odometer: Int64
    @NSManaged public var vehicle: Car?
    @NSManaged public var vendor: Vendor?
    @NSManaged public var fuel: Fuel?

//
    public var wrappedOdometer: Int64 {
        odometer
    }
}
