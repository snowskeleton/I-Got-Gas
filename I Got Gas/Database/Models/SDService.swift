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
    var odometer: Int?
    
    var isFuel: Bool = false
    var costPerGallon: Double = 0.0
    var isFullTank: Bool = true
    var gallons: Double = 0.0
    
    @Relationship
    var vendor: SDVendor?
    
    @Relationship
    var car: SDCar?
    
    init(
        cost: Double,
        datePurchased: Date,
        dateCompleted: Date,
        note: String,
        odometer: Int
    ) {
        self.cost = cost
        self.datePurchased = datePurchased
        self.dateCompleted = dateCompleted
        self.note = note
        self.odometer = odometer
    }
}
