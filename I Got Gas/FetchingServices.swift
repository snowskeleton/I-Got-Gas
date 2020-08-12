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

func FetchServices(howMany: Int, carID: String, filters: [String]) -> FetchRequest<Service> {
    let fetchRequest: FetchRequest<Service>
    let request: NSFetchRequest<Service> = Service.fetchRequest()
    var services: FetchedResults<Service> { fetchRequest.wrappedValue }
    var subPredicates : [NSPredicate] = []

    for i in filters {
        let subPredicate = NSPredicate(format: "\(i)" )
        subPredicates.append(subPredicate)
    }
    
    request.fetchLimit = howMany
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subPredicates)

    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false), NSSortDescriptor(key: "cost", ascending: true)]
    fetchRequest = FetchRequest<Service>(fetchRequest: request)
    
    return fetchRequest
}
