//
//  Car+CoreDataProperties.swift
//  
//
//  Created by Isaac Lyons on 10/21/20.
//
//

import Foundation
import CoreData


extension Car {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Car> {
        return NSFetchRequest<Car>(entityName: "Car")
    }

    @NSManaged public var costPerGallon: Double
    @NSManaged public var costPerMile: Double
    @NSManaged public var id: String?
    @NSManaged public var lastFillup: Date?
    @NSManaged public var lastFuelDate: Date?
    @NSManaged public var make: String?
    @NSManaged public var model: String?
    @NSManaged public var name: String?
    @NSManaged public var odometer: Int64
    @NSManaged public var plate: String?
    @NSManaged public var startingOdometer: Int64
    @NSManaged public var vin: String?
    @NSManaged public var year: String?
    @NSManaged public var futureSerevice: NSSet?
    @NSManaged public var services: NSSet?

}

// MARK: Generated accessors for futureSerevice
extension Car {

    @objc(addFutureSereviceObject:)
    @NSManaged public func addToFutureSerevice(_ value: FutureService)

    @objc(removeFutureSereviceObject:)
    @NSManaged public func removeFromFutureSerevice(_ value: FutureService)

    @objc(addFutureSerevice:)
    @NSManaged public func addToFutureSerevice(_ values: NSSet)

    @objc(removeFutureSerevice:)
    @NSManaged public func removeFromFutureSerevice(_ values: NSSet)

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
