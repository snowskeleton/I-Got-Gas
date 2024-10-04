//
//  SDService.swift
//  I Got Gas
//
//  Created by snow on 10/4/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftData

@Model
class SDService: Identifiable {
    @Attribute(.unique)
    var localId: String = UUID().uuidString
    var icloudId: String = UUID().uuidString
    var cost: Double = 0.0
    var datePurchased = Date()
    var dateCompleted = Date()
    var note: String = ""
    var odometer: String?
    
    @Relationship
    var vendor: SDVendor?
    
    var car: SDCar?
    
    init(
        cost: Double,
        datePurchased: Date,
        dateCompleted: Date,
        note: String,
        odometer: String
    ) {
        self.cost = cost
        self.datePurchased = datePurchased
        self.dateCompleted = dateCompleted
        self.note = note
        self.odometer = odometer
    }
}
