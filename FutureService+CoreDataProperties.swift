//
//  FutureService+CoreDataProperties.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/12/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//
//

import Foundation
import CoreData


extension FutureService {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FutureService> {
        return NSFetchRequest<FutureService>(entityName: "FutureService")
    }

    @NSManaged public var name: String?
    @NSManaged public var date: Date?
    @NSManaged public var odometer: Int64
    @NSManaged public var milesLeft: Int64
    @NSManaged public var startingMiles: Int64
    @NSManaged public var months: Int64
    @NSManaged public var note: String?
    @NSManaged public var vehicle: Car?

}
