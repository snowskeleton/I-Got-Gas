//
//  FetchingServices.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/7/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation
import CoreData
import SwiftUI

struct Fetch {
    static func car(carID: String) -> FetchRequest<Car> {
        let fetchRequest: FetchRequest<Car>
        let request: NSFetchRequest<Car> = I_Got_Gas.Car.fetchRequest()
        var car: FetchedResults<Car> { fetchRequest.wrappedValue }
        request.predicate = NSPredicate(format: "id = '\(carID)'")
        request.sortDescriptors = []
        fetchRequest = FetchRequest<Car>(fetchRequest: request)
        
        return fetchRequest
    }
    
    static func services(howMany: Int, carID: String, filters: [String]) -> FetchRequest<Service> {
        let fetchRequest: FetchRequest<Service>
        let request: NSFetchRequest<Service> = Service.fetchRequest()
        var services: FetchedResults<Service> { fetchRequest.wrappedValue }
        var subPredicates : [NSPredicate] = []
        
        for i in filters {
            let subPredicate = NSPredicate(format: "\(i)" )
            subPredicates.append(subPredicate)
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subPredicates)
        
        request.fetchLimit = howMany
        
        request.sortDescriptors = [NSSortDescriptor(
                                    key: "date",
                                    ascending: false),
                                   NSSortDescriptor(
                                    key: "cost",
                                    ascending: true)]
        fetchRequest = FetchRequest<Service>(fetchRequest: request)
        
        return fetchRequest
    }
    
    static func futureServices(howMany: Int, carID: String, important: Bool? = false) -> FetchRequest<FutureService> {
        let fetchRequest: FetchRequest<FutureService>
        let request: NSFetchRequest<FutureService> = FutureService.fetchRequest()
        var services: FetchedResults<FutureService> { fetchRequest.wrappedValue }
        request.predicate = NSPredicate(format: "vehicle.id = '\(carID)'")
        
        request.fetchLimit = howMany
        
        if important! {
            request.sortDescriptors! += [(NSSortDescriptor(key: "important", ascending: false))]
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "targetOdometer",
                ascending: true),
            NSSortDescriptor(
                key: "date",
                ascending: true)
        ]
        
        fetchRequest = FetchRequest<FutureService>(fetchRequest: request)
        return fetchRequest
    }
}
