//
//  Vendor+CoreDataProperties.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/30/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//
//

import Foundation
import CoreData


extension Vendor {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Vendor> {
        return NSFetchRequest<Vendor>(entityName: "Vendor")
    }

    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var name: String?
    @NSManaged public var services: NSSet?

}

// MARK: Generated accessors for services
extension Vendor {

    @objc(addServicesObject:)
    @NSManaged public func addToServices(_ value: Service)

    @objc(removeServicesObject:)
    @NSManaged public func removeFromServices(_ value: Service)

    @objc(addServices:)
    @NSManaged public func addToServices(_ values: NSSet)

    @objc(removeServices:)
    @NSManaged public func removeFromServices(_ values: NSSet)

}
