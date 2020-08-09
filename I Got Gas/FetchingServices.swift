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

func FetchServices(howMany: Int, carID: String) -> FetchRequest<Service> {
    let fetchRequest: FetchRequest<Service>
    var services: FetchedResults<Service> { fetchRequest.wrappedValue }
    
    let request: NSFetchRequest<Service> = Service.fetchRequest()
    request.fetchLimit = howMany
    request.predicate = NSPredicate(format: "vehicle.id = %@", carID)
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false), NSSortDescriptor(key: "cost", ascending: true)]
    fetchRequest = FetchRequest<Service>(fetchRequest: request)
    
    return fetchRequest
}
