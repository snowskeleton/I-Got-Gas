//
//  Car+CoreDataProperties.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/30/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//
//

import Foundation
import CoreData


extension Car {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Car> {
        return NSFetchRequest<Car>(entityName: "Car")
    }

    @NSManaged public var id: String?
    @NSManaged public var make: String?
    @NSManaged public var model: String?
    @NSManaged public var name: String?
    @NSManaged public var odometer: Int64
    @NSManaged public var photo: Data?
    @NSManaged public var plate: String?
    @NSManaged public var vin: String?
    @NSManaged public var year: String?
    @NSManaged public var services: NSSet?

}

// MARK: Generated accessors for services
extension Car {

    @objc(addServicesObject:)
    @NSManaged public func addToServices(_ value: Service)

    @objc(removeServicesObject:)
    @NSManaged public func removeFromServices(_ value: Service)

    @objc(addServices:)
    @NSManaged public func addToServices(_ values: NSSet)

    @objc(removeServices:)
    @NSManaged public func removeFromServices(_ values: NSSet)

}
