//
//  FilterCar.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import CoreData
import SwiftUI

struct FilterCar: View {
    var fetchRequest: FetchRequest<Car>
    var body: some View {
List(FetchRequest)
        
    }
    init(filter: String) {
    fetchRequest = FetchRequest<Car>(entity: Car.entity(), sortDescriptors: [], predicate: NSPredicate(format: "id BEGINSWITH %@", filter))
    }
}
